#import "../template.typ": *

// =============================================================================
//  CASO DE USO — UC-VID-003: Modificação de velocidade de reprodução
// =============================================================================

== UC-VID-003 — Modificação de velocidade de reprodução (Speed Adjust)

=== Cabeçalho

#tab([Caso de uso UC-VID-003 — Modificação de velocidade de reprodução (Speed Adjust)],
  tabela-campos(
    [ID do Caso de Uso], [UC-VID-003],
    [Nome], [Modificação de velocidade de reprodução (Speed Adjust)],
    [Versão], [v1.1],
    [Autor], [Grupo PL3-G7],
    [Data], [2026-10-21],
    [Objetivo], [Alterar a velocidade de reprodução de um vídeo (aceleração ou desaceleração), recalculando a duração do vídeo e ajustando em conformidade as faixas de vídeo e áudio.],
    [Âmbito], [Módulo de Edição Multimédia / Pipeline de Processamento Temporal do PictuRAS],
    [Ator Principal], [Utilizador (qualquer perfil de autenticação)],
    [_Stakeholders_ e Interesses], [
      - *Utilizador*: Deseja acelerar ou abrandar o vídeo de forma intuitiva, mantendo a inteligibilidade do áudio ou a fluidez da imagem.
      - *Operador da Infraestrutura*: Deseja controlar o esforço de transcodificação gerado por interpolação de frames em desacelerações extremas.
      - *Equipa de Produto PictuRAS*: Assegurar uma transição simples entre predefinições e permitir configurações avançadas em perfis pagos.
    ],
    [Pré-condições], [
      - Um vídeo suportado encontra-se carregado e validado no editor PictuRAS.
      - Os metadados de duração, taxa de fotogramas (FPS) e taxa de amostragem de áudio foram extraídos com sucesso.
      - O utilizador tem quota diária de operações disponível.
    ],
    [_Trigger_], [O utilizador seleciona a ferramenta "Velocidade" no painel de ferramentas de vídeo.],
  ),
)

=== Fluxo Principal

#tab([UC-VID-003 — Fluxo principal],
  tabela(
    colunas: (1.2cm, 1fr, 1fr),
    [Passo], [Ação do Ator], [Resposta do Sistema],
    [1], [O utilizador aciona a ferramenta "Velocidade".], [O sistema exibe o painel de ajuste de velocidade com botões de atalho rápido (0.25x, 0.5x, 1x, 2x, 4x), uma barra deslizante contínua e a opção de preservação de tom de áudio (_pitch correction_).],
    [2], [O utilizador define o fator de velocidade pretendido e assinala se pretende manter a correção de tom de áudio.], [O sistema valida o multiplicador, calcula a duração estimada resultante (D_nova = D_original / fator) e atualiza a indicação de duração prevista na interface.],
    [3], [O utilizador solicita a pré-visualização do resultado.], [O sistema reproduz um excerto do vídeo ajustado em tempo real no reprodutor integrado.],
    [4], [O utilizador confirma a operação de alteração de velocidade.], [O sistema valida as restrições do perfil, bloqueia novas edições e submete a tarefa de reamostragem temporal à fila de tarefas de processamento assíncrono.],
    [5], [—], [O serviço de vídeo processa a alteração de velocidade nos fluxos de vídeo (ajuste de _PTS_ e amostragem de fotogramas) e aplica os filtros de estiramento temporal ao fluxo de áudio (_time-stretch_).],
    [6], [—], [O sistema grava o vídeo resultante no projeto, deduz uma operação da quota quando aplicável (RNG-01), desbloqueia a interface e apresenta o novo vídeo gerado.],
  ),
)

=== Fluxos Alternativos

#tab([UC-VID-003 — Fluxos alternativos],
  tabela(
    colunas: (4cm, 1fr),
    [Fluxo], [Descrição (passo de origem: condição -> comportamento -> retorno)],
    [FA1 – Aplicação de Velocidade a Segmento Específico], [No Passo 2, o utilizador define marcadores temporais de início e fim na timeline para limitar a alteração de velocidade apenas a esse intervalo. O sistema divide logicamente o vídeo, aplica o novo fator exclusivamente ao excerto demarcado e concatena os blocos antes de submeter no Passo 4.],
    [FA2 – Remoção da Faixa de Áudio em Aceleração Elevada], [No Passo 2, o utilizador opta deliberadamente por silenciar/remover a faixa de áudio em vez de aplicar compressão temporal de som. No Passo 5, o sistema descarta o fluxo de áudio e transcodifica unicamente o fluxo de vídeo acelerado.],
  ),
)

=== Exceções

#tab([UC-VID-003 — Exceções],
  tabela(
    colunas: (1fr, 1fr),
    [Condição], [Comportamento do Sistema],
    [Multiplicador de velocidade fora dos limites permitidos para o perfil], [Se o utilizador inserir um valor fora do intervalo suportado para o seu perfil (ex.: utilizador Anónimo a selecionar 0.25x ou 4x quando o seu limite é 0.5x a 2x), o sistema bloqueia a confirmação no Passo 4, repõe o limite permitido mais próximo e notifica o utilizador da restrição do plano.],
    [Incompatibilidade de amostragem de áudio em desaceleração/aceleração extrema], [No Passo 5, se o codec ou a taxa de amostragem de áudio não suportar a taxa de processamento necessária para a velocidade definida, provocando ruído ou buffer underrun, o processador multimédia desativa automaticamente o áudio no ficheiro de saída, emite aviso ao utilizador informando que o vídeo foi processado sem som por incompatibilidade da faixa de áudio e finaliza a tarefa.],
    [Falha por estouro de temporização (_timeout_) no nó de processamento multimédia], [Caso a geração de fotogramas interpolados em modo de câmara lenta prolongada exceda o tempo máximo de execução por tarefa, o sistema aborta a operação. O utilizador é notificado da falha por tempo excedido, o vídeo inicial é mantido intacto e a quota não é deduzida.],
  ),
)

=== Pós-condições

#tabela(
  colunas: (4cm, 1fr),
  [Tipo], [Resultado],
  [Garantia de Sucesso], [É disponibilizado no projeto um novo ficheiro de vídeo com a duração ajustada proporcionalmente ao multiplicador escolhido; os fluxos de vídeo e áudio mantêm-se íntegros e reproduzíveis; a operação é debitada na quota do utilizador.],
  [Garantia Mínima], [O ficheiro de vídeo original mantém-se intacto; ficheiros temporários do processador são limpos; nenhuma dedução é efetuada na quota de operações da conta.],
)

=== Regras de Negócio e Restrições

#tabela(
  colunas: (1.4cm, 1fr),
  [ID], [Regra],
  [RN1], [Limites de velocidade por perfil: Utilizadores Anónimos podem ajustar a velocidade entre [0.5x, 2.0x]; Utilizadores Registados entre [0.25x, 4.0x]; Utilizadores Premium entre [0.1x, 10.0x].],
  [RN2], [Correção de tom (_Pitch Correction_): O algoritmo de manutenção de tom vocal só é garantido para o intervalo de [0.5x, 2.0x]. Fora deste intervalo, o sistema avisa o utilizador para a potencial ocorrência de artefactos sonoros.],
  [RN3], [Duração máxima pós-ajuste: o vídeo resultante de um abrandamento não pode exceder a duração máxima de vídeo do perfil (RNG-04).],
  [RN4], [Consumo de quota: uma operação de modificação de velocidade concluída com sucesso conta como uma operação do limite diário do perfil (RNG-01).],
)

=== Assunções

#tabela(
  colunas: (1.4cm, 1fr),
  [ID], [Assunção],
  [A1], [A biblioteca de backend (como FFmpeg ou equivalente) tem compilados os filtros necessários para processamento conjunto de _setpts_ (vídeo) e _atempo_ (áudio).],
  [A2], [O navegador web tem suporte nativo para alterar a propriedade _playbackRate_ do elemento multimédia HTML5 para assegurar uma pré-visualização ágil no cliente antes da confirmação do processamento.],
  [A3], [O vídeo de origem possui uma taxa de fotogramas constante (CFR) ou é convertível para CFR durante a transcodificação sem perda de sincronismo com o áudio.],
)

=== Questões em Aberto

#tabela(
  colunas: (1.4cm, 1fr, 5cm),
  [ID], [Questão], [Resolução],
  [Q1], [Nos abrandamentos acentuados (inferiores a 0.5x), o sistema deve aplicar interpolação de movimento por estimativa de fluxo ótico (_optical flow_) para evitar saltos visuais ou deve limitar-se à duplicação simples de frames?], [Decidida → apenas duplicação simples de fotogramas no MVP, por custo computacional. DQ-009, REQ-VID-SPD-007.],
  [Q2], [Em caso de acelerações extremas (>4x), a faixa de áudio deve ser silenciada por omissão para evitar distorção ininteligível ou a escolha deve caber sempre ao utilizador?], [Decidida → a escolha cabe ao utilizador (FA2); fora de [0.5x, 2.0x] o sistema avisa da possível distorção (RN2). REQ-VID-SPD-008, REQ-VID-SPD-010.],
)