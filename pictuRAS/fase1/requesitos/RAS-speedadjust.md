# Speed Adjust
### Casos de Uso · Fase 1: Suporte a Vídeo no PictuRAS

---

## 0. Identificação

| **Campo** | **Valor** |
|-----------|-----------|
| **Grupo / Equipa** | Grupo 1 |
| **Autores** | Duarte Pinto Bravo (*pg63951*), Ivo Costa Sousa (*pg63976*), Tiago Gonçalves de Melo (*pg65445*) |
| **Data** | 2026-10-05 |
| **Versão do documento** | v1.0 |
| **Unidade Curricular** | Requisitos e Arquiteturas de Software — MEI, Universidade do Minho |

---

## 1. Funcionalidade de vídeo escolhida

| **Campo** | **Valor** |
|-----------|-----------|
| **Funcionalidade** | Modificação de velocidade de reprodução (*Speed Adjust / Time-stretch*) |
| **Perfil(s) de utilizador abrangido(s)** | Anónimo, registado e premium. O ajuste de velocidade é uma operação global de modificação de ritmo que deve estar disponível para todos os perfis, variando nas restrições de amplitude do multiplicador e cotas de processamento. |

**Justificação no contexto do MVP**
A alteração de velocidade de reprodução é uma das funcionalidades temporais mais procuradas para criação de efeitos de câmara lenta (*slow-motion*) e avanço rápido (*timelapse*). Permite validar o suporte a reamostragem de carimbos temporais de apresentação (*presentation timestamps - PTS*), interpolação ou descarte de fotogramas e algoritmos de estiramento temporal de áudio com preservação de tom. Sem esta capacidade, o PictuRAS não consegue manipular a dimensão temporal contínua dos fluxos multimédia.

---

## 2. Caso de Uso

### 2.1 Cabeçalho

| **Secção** | **Detalhes** |
|------------|--------------|
| **ID do Caso de Uso** | UC-VID-003 |
| **Nome** | Modificação de velocidade de reprodução (*Speed Adjust*) |
| **Versão** | v1.0 |
| **Autor** | Tiago Melo & Ivo Sousa |
| **Data** | 2026-10-05 |
| **Objetivo** | Alterar a velocidade de reprodução de um vídeo (aceleração ou desaceleração), recalculando a duração do vídeo e ajustando em conformidade as faixas de vídeo e áudio. |
| **Âmbito** | Módulo de Edição Multimédia / Pipeline de Processamento Temporal do PictuRAS |
| **Ator Principal** | Utilizador (qualquer perfil de autenticação) |
| **Stakeholders e Interesses** | - **Utilizador**: Deseja acelerar ou abrandar o vídeo de forma intuitiva, mantendo a inteligibilidade do áudio ou a fluidez da imagem.<br>- **Operador da Infraestrutura**: Deseja controlar o esforço de transcodificação gerado por interpolação de frames em desacelerações extremas.<br>- **Equipa de Produto PictuRAS**: Assegurar uma transição simples entre predefinições e permitir configurações avançadas em perfis pagos. |
| **Pré-condições** | - Um vídeo suportado encontra-se carregado e validado no editor PictuRAS.<br>- Os metadados de duração, taxa de fotogramas (FPS) e taxa de amostragem de áudio foram extraídos com sucesso.<br>- O utilizador tem quota diária de operações disponível. |
| **Trigger** | O utilizador seleciona a ferramenta "Velocidade" no painel de ferramentas de vídeo. |

### 2.2 Fluxo Principal

| **Passo** | **Ação do Ator** | **Resposta do Sistema** |
|-----------|------------------|-------------------------|
| 1 | O utilizador aciona a ferramenta "Velocidade". | O sistema exibe o painel de ajuste de velocidade com botões de atalho rápido (0.25x, 0.5x, 1x, 2x, 4x), uma barra deslizante contínua e a opção de preservação de tom de áudio (*pitch correction*). |
| 2 | O utilizador define o fator de velocidade pretendido e assinala se pretende manter a correção de tom de áudio. | O sistema valida o multiplicador, calcula a duração estimada resultante ($D_{\text{nova}} = \frac{D_{\text{original}}}{\text{fator}}$) e atualiza a indicação de duração prevista na interface. |
| 3 | O utilizador solicita a pré-visualização do resultado. | O sistema reproduz um excerto do vídeo ajustado em tempo real no reprodutor integrado. |
| 4 | O utilizador confirma a operação de alteração de velocidade. | O sistema valida as restrições do perfil, bloqueia novas edições e submete a tarefa de reamostragem temporal à fila de tarefas de processamento assíncrono. |
| 5 | — | O serviço de vídeo processa a alteração de velocidade nos fluxos de vídeo (ajuste de *PTS* e amostragem de fotogramas) e aplica os filtros de estiramento temporal ao fluxo de áudio (*time-stretch*). |
| 6 | — | O sistema grava o vídeo resultante no projeto, deduz uma operação na quota do utilizador, desbloqueia a interface e apresenta o novo vídeo gerado. |

### 2.3 Fluxos Alternativos

| **Fluxo** | **Descrição** |
|-----------|---------------|
| FA1 – Aplicação de Velocidade a Segmento Específico | No Passo 2, o utilizador define marcadores temporais de início e fim na timeline para limitar a alteração de velocidade apenas a esse intervalo. O sistema divide logicamente o vídeo, aplica o novo fator exclusivamente ao excerto demarcado e concatena os blocos antes de submeter no Passo 4. |
| FA2 – Remoção da Faixa de Áudio em Aceleração Elevada | No Passo 2, o utilizador opta deliberadamente por silenciar/remover a faixa de áudio em vez de aplicar compressão temporal de som. No Passo 5, o sistema descarta o fluxo de áudio e transcodifica unicamente o fluxo de vídeo acelerado. |

### 2.4 Exceções

| **Condição** | **Comportamento do Sistema** |
|--------------|------------------------------|
| Multiplicador de velocidade fora dos limites permitidos para o perfil | Se o utilizador inserir um valor fora do intervalo suportado para o seu perfil (ex.: utilizador anónimo a selecionar 0.1x ou 10x quando o seu limite é 0.25x a 4x), o sistema bloqueia a confirmação no Passo 4, repõe o limite permitido mais próximo e notifica o utilizador da restrição do plano. |
| Incompatibilidade de amostragem de áudio em desaceleração/aceleração extrema | No Passo 5, se o codec ou a taxa de amostragem de áudio não suportar a taxa de processamento necessária para a velocidade definida, provocando ruído ou buffer underrun, o processador multimédia desativa automaticamente o áudio no ficheiro de saída, emite aviso ao utilizador informando que o vídeo foi processado sem som por incompatibilidade da faixa de áudio e finaliza a tarefa. |
| Falha por estouro de temporização (*timeout*) no nó de processamento multimédia | Caso a geração de fotogramas interpolados em modo de câmara lenta prolongada exceda o tempo máximo de execução por tarefa, o sistema aborta a operação. O utilizador é notificado da falha por tempo excedido, o vídeo inicial é mantido intacto e a quota não é deduzida. |

### 2.5 Pós-condições

| **Tipo** | **Resultado** |
|----------|---------------|
| Garantia de Sucesso | É disponibilizado no projeto um novo ficheiro de vídeo com a duração ajustada proporcionalmente ao multiplicador escolhido; os fluxos de vídeo e áudio mantêm-se íntegros e reproduzíveis; a operação é debitada na quota do utilizador. |
| Garantia Mínima | O ficheiro de vídeo original mantém-se intacto; ficheiros temporários do processador são limpos; nenhuma dedução é efetuada na quota de operações da conta. |

### 2.6 Regras de Negócio e Restrições

| **ID** | **Regra** |
|--------|-----------|
| RN1 | Limites de velocidade por perfil: Utilizadores Anónimos podem ajustar a velocidade entre $[0.5\text{x}, 2.0\text{x}]$; Utilizadores Registados entre $[0.25\text{x}, 4.0\text{x}]$; Utilizadores Premium entre $[0.1\text{x}, 10.0\text{x}]$. |
| RN2 | Correção de tom (*Pitch Correction*): O algoritmo de manutenção de tom vocal só é garantido para o intervalo de $[0.5\text{x}, 2.0\text{x}]$. Fora deste intervalo, o sistema avisa o utilizador para a potencial ocorrência de artefactos sonoros. |
| RN3 | Duração máxima pós-ajuste: O vídeo resultante de um abrandamento temporal não pode exceder o teto máximo de duração de vídeo estipulado para o perfil do utilizador. |
| RN4 | Consumo de quota: Uma operação de modificação de velocidade concluída com sucesso consome 1 crédito diário da quota de vídeo da conta. |

### 2.7 Assunções

| **ID** | **Assunção** |
|--------|--------------|
| A1 | A biblioteca de backend (como FFmpeg ou equivalente) tem compilados os filtros necessários para processamento conjunto de *setpts* (vídeo) e *atempo* (áudio). |
| A2 | O navegador web tem suporte nativo para alterar a propriedade `playbackRate` do elemento multimédia HTML5 para assegurar uma pré-visualização ágil no cliente antes da confirmação do processamento. |
| A3 | O vídeo de origem possui uma taxa de fotogramas constante (*CFR*) ou é convertível para CFR durante a transcodificação sem perda de sincronismo com o áudio. |

### 2.8 Questões em Aberto

| **ID** | **Questão** |
|--------|-------------|
| Q1 | Nos abrandamentos acentuados (inferiores a 0.5x), o sistema deve aplicar interpolação de movimento por estimativa de fluxo ótico (*optical flow*) para evitar saltos visuais ou deve limitar-se à duplicação simples de frames? |
| Q2 | Em caso de acelerações extremas (>4x), a faixa de áudio deve ser silenciada por omissão para evitar distorção ininteligível ou a escolha deve caber sempre ao utilizador? |

---

## 3. Utilização de agentes de IA

| **Ferramenta / *skill*** | **Tarefa apoiada** | **Validação realizada pela equipa** |
|--------------------------|--------------------|--------------------------------------|
| Google Gemini | Modelação dos parâmetros do fluxo de reamostragem temporal, identificação de exceções ligadas à preservação de tom de áudio (*pitch*) e calibração das regras de limites de multiplicador de velocidade. | Revisão minuciosa pela equipa: validação das faixas de aceleração aplicáveis aos diferentes perfis, verificação da coerência das fórmulas de duração temporal e definição da garantia mínima do ficheiro. |

---

## 4. Especificação de Requisitos do Sistema (ERS)

**Caso de Uso:** UC-VID-003 — Modificação de velocidade de reprodução (*Speed Adjust*)  
**Versão do dossiê:** v1.1  
**Baseline do Exercício 1:** v1.0 (Requisitos originais REQ-VID-SPD-001 a REQ-VID-SPD-009)

### 4.1 Requisitos da ERS

#### 4.1.1 Requisitos Funcionais

| **ID** | **Requisito** | **Prioridade** | **Evolução** | **Novo/Alt** | **Origem (UC / RN / decisão)** | **Justificação** | **Critério de aceitação / verificação** |
|--------|---------------|----------------|--------------|--------------|--------------------------------|-----------------|----------------------------------------|
| REQ-VID-SPD-001 | O sistema deve disponibilizar controlos interativos na interface para seleção do multiplicador de velocidade e ativação de correção de tom (*pitch*). | Deve ter | Refinado | NOVO | Passo 1 | É a interface primordial para a parametrização da ferramenta. | Dado que o painel da ferramenta é aberto, Quando o utilizador interage, Então são visíveis atalhos predefinidos, barra deslizante e checkbox de *pitch*. |
| REQ-VID-SPD-002 | O sistema deve calcular dinamicamente e exibir a duração estimada do novo vídeo com base no multiplicador selecionado. | Deve ter | Refinado | NOVO | Passo 2 | Informa o utilizador do impacto temporal antes da submissão. | Dado um vídeo de 10s, Quando o utilizador ajusta a velocidade para 2.0x, Então a interface exibe imediatamente "Duração prevista: 5s". |
| REQ-VID-SPD-004 | O sistema deve validar e impor os limites de velocidade definidos por perfil (Anónimo: 0.5x-2.0x, Registado: 0.25x-4.0x, Premium: 0.1x-10.0x). | Deve ter | Refinado | NOVO | E1, RN1 | Garante a segmentação de perfis do modelo de negócio e evita abusos de processamento. | Dado um utilizador anónimo, Quando tenta introduzir o valor 4.0x, Então o sistema recusa e força o limite máximo de 2.0x. |
| REQ-VID-SPD-005 | O sistema deve permitir a aplicação da velocidade apenas a um segmento demarcado do vídeo, mantendo o restante inalterado. | Poderia ter | Refinado | NOVO | FA1 | Oferece flexibilidade criativa avançada (ex: efeito *speed ramp*). | Dado um vídeo e marcadores num sub-segmento, Quando processado a 2.0x, Então apenas a porção demarcada é acelerada no ficheiro final. |
| REQ-VID-SPD-006 | O sistema deve descartar a faixa de áudio se explicitamente solicitado ou se for detetada incompatibilidade (buffer underrun) em velocidades extremas. | Deve ter | Refinado | NOVO | FA2, E2 | Evita falhas críticas de codificação que corromperiam o ficheiro de saída. | Dado um pedido de aceleração de 8.0x (incompatível com o samplerate de áudio), Quando processado, Então o vídeo gerado não possui faixa de áudio e o utilizador é alertado. |
| REQ-VID-SPD-007 | O sistema deve bloquear a operação se o prolongamento temporal provocado pela desaceleração exceder o limite de duração máxima do perfil. | Deve ter | Refinado | NOVO | RN3 | Mantém a consistência com as regras globais de restrição de armazenamento/processamento da plataforma. | Dado um limite de 60s, Quando um vídeo de 40s é retardado a 0.5x (resultando em 80s), Então a submissão é inibida com notificação. |
| REQ-VID-SPD-009 | O sistema deve debitar 1 crédito na quota diária de operações do utilizador apenas após a geração bem-sucedida do novo ficheiro. | Deve ter | Refinado | ALT | Passo 6, RN4 | Regula a utilização dos recursos do sistema conforme os planos do PictuRAS. | Dado um saldo de N créditos, Quando um ajuste de velocidade falha por *timeout*, Então o saldo mantém-se N. Quando conclui com sucesso, passa a N-1. |
| REQ-VID-SPD-010 | O sistema deve reportar de forma clara o estado do processamento multimédia (em fila, em execução, concluído). | Deve ter | Novo | NOVO | Passo 5, Passo 6, Secção 4.1.3 | O processamento de reamostragem pode ser demorado, exigindo *feedback* de UX. | Dado que o ficheiro está em renderização, Quando o utilizador visualiza o ecrã, Então observa um indicador de progresso ativo que bloqueia novas edições. |

#### 4.1.2 Requisitos Não Funcionais e de Qualidade

| **ID** | **Requisito** | **Característica ISO/IEC 25010** | **Alvo MVP** | **Alvo produção** | **Evolução** | **Origem (UC / DQ)** | **Critério de aceitação / verificação** |
|--------|---------------|----------------------------------|--------------|------------------|--------------|----------------------|----------------------------------------|
| REQ-VID-SPD-003 | O sistema deve aplicar correção de tom (*pitch*) evitando distorções vocais percetíveis no intervalo de $[0.5\text{x}, 2.0\text{x}]$. | Adequação Funcional (Maturidade) | Algoritmo *atempo* padrão | Algoritmo *Rubberband* avançado | Refinado | Passo 5, RN2, DQ-001 | Dado o processamento de voz humana a 1.5x, Quando escutado o ficheiro resultante, Então a frequência base da voz deve manter-se igual à original (sem efeito "esquilo"). |
| REQ-VID-SPD-008 | O sistema deve proteger a infraestrutura abortando operações que ultrapassem o tempo limite de processamento (*timeout*) sem degradar a estabilidade. | Fiabilidade (Tolerância a Falhas / Recuperabilidade) | Timeout = 120s por job | Timeout escalável dinamicamente por perfil | Refinado | E3, Garantia Mínima, DQ-002 | Dado um job de interpolação excessivamente pesado, Quando o tempo de CPU supera o limite, Então o processo morre graciosamente e a UI repõe o ficheiro original. |
| REQ-VID-SPD-011 | A geração dos fotogramas ajustados deve assegurar uma taxa de desempenho suficiente para evitar congestionamento na fila (*queue*). | Eficiência de Desempenho (Comportamento Temporal) | Capacidade de 1 job simultâneo por worker | Capacidade de paralelização intrínseca | Novo | Secção 4.1.3, DQ-003 | Dado o envio de um pedido a 2.0x de um vídeo 720p de 10s, Quando submetido, Então o tempo estrito de renderização não deve exceder 5s num *worker* livre. |

#### 4.1.3 Verificação da completude e dos limites do âmbito

| **Tópico a verificar** | **Aplicável?** | **Decisão / justificação** | **Requisito(s) relacionado(s)** |
|-----------------------|---------------|----------------------------|--------------------------------|
| Formato, codec, duração e dimensão do vídeo | Sim | Diretamente ligado aos cálculos de recálculo temporal e suportabilidade dos codecs para as faixas de áudio a altas velocidades. | REQ-VID-SPD-002, REQ-VID-SPD-006, REQ-VID-SPD-007 |
| Estado, progresso, cancelamento e resultado | Sim | A transcodificação profunda requer *feedback* constante ao utilizador devido à latência da operação. | REQ-VID-SPD-010 |
| Falhas durante o processamento | Sim | Extrema relevância: *timeouts* provocados por desacelerações extremas e falhas em buffers de áudio requerem tratamento. | REQ-VID-SPD-006, REQ-VID-SPD-008 |
| Persistência e expiração dos ficheiros | Não | A retenção do ficheiro obedece às regras globais de *storage* do projeto (fora do âmbito específico do *speed adjust*). | N/A |
| Perfis e contagem de operações | Sim | A capacidade de variar drasticamente o tempo introduz esforço de CPU que tem de ser filtrado por escalões de utilizador. | REQ-VID-SPD-004, REQ-VID-SPD-009 |
| Encadeamento de ferramentas e processamento em lote | Não | Funcionalidade atua isoladamente no fluxo, a concatenação de efeitos em lote fica fora da ERS do MVP. | N/A |

### 4.2 Impacto no sistema existente

| **Elemento existente afetado** | **Impacto (Manter / Estender / Alterar)** | **Descrição do impacto** | **Requisito(s) relacionado(s)** |
|--------------------------------|-------------------------------------------|--------------------------|--------------------------------|
| Motor de pré-visualização (Cliente Web) | Estender | Necessidade de injeção da propriedade HTML5 `playbackRate` para simulação direta do ritmo (sem dependência de codificação backend) para o Passo 3. | REQ-VID-SPD-001, REQ-VID-SPD-002 |
| Fila assíncrona de processamento e *Workers* | Alterar | Integração de novos fluxogramas no FFmpeg para manuseio combinado dos filtros `setpts` e `atempo`. Requer reconfiguração de políticas de *timeout* dos *workers* (mais complacentes com vídeo). | REQ-VID-SPD-003, REQ-VID-SPD-006, REQ-VID-SPD-008 |
| Mecanismo de contabilização de operações e UI | Estender | Reconhecer a submissão de vídeos para processamento temporal como 1 consumível da quota, bem como adicionar UI de progresso de tarefa longa. | REQ-VID-SPD-004, REQ-VID-SPD-009, REQ-VID-SPD-010 |

### 4.3 Matriz de Rastreabilidade Atualizada

| **Elemento de origem** | **Descrição abreviada** | **Requisito(s) relacionado(s)** |
|------------------------|-------------------------|--------------------------------|
| Passo 1 | UI com atalhos, barra deslizante e opção de *pitch* | REQ-VID-SPD-001 |
| Passo 2 | Dinâmica de UI: recálculo previsional da nova duração | REQ-VID-SPD-002 |
| FA1 | Aceleração circunscrita e limitável a segmento isolado | REQ-VID-SPD-005 |
| FA2, E2 | Auto-mute/Supressão de áudio para evitar estoiros de amostragem | REQ-VID-SPD-006 |
| E1, RN1 | Controlo do multiplicador com base no *tier* de perfil | REQ-VID-SPD-004 |
| E3, Garantia Mínima, DQ-002 | Graceful termination após *timeout* limitando uso excessivo de recursos | REQ-VID-SPD-008 |
| RN2, DQ-001 | Correção qualitativa da formante vocal em gama segura (0.5x-2.0x) | REQ-VID-SPD-003 |
| RN3 | Validação defensiva contra prolongamentos ilegais de vídeos | REQ-VID-SPD-007 |
| RN4, Passo 6 | Sistema de dedução de carteira de créditos diários | REQ-VID-SPD-009 |
| Secção 4.1.3, DQ-003 | Requisitos estritos de comunicação de estado/eficiência | REQ-VID-SPD-010, REQ-VID-SPD-011 |

**Decisões de qualidade introduzidas nesta aula**

| **ID** | **Decisão de qualidade** | **Justificação** | **Requisito(s) relacionado(s)** |
|--------|--------------------------|-----------------|--------------------------------|
| DQ-001 | Utilização de filtros nativos padrão de correção de tempo no MVP. | Algoritmos acústicos hiper-avançados consomem muito CPU. Para o MVP, a correção nativa suportável até ao rácio de 2.0x é o balanço ideal entre qualidade percetível e custo de infraestrutura. | REQ-VID-SPD-003 |
| DQ-002 | Definição de barreira fixa de *timeout* aos jobs do backend. | Desacelerar um vídeo a 0.1x decuplica o tamanho/frames, o que pode bloquear *workers* indefinidamente. Impor um limite rígido (ex: 120s no MVP) protege a disponibilidade global. | REQ-VID-SPD-008 |
| DQ-003 | Limitação do poder computacional a interpolação simples de frames. | Para evitar latências insustentáveis num serviço web gratuito, abdicamos do *optical flow* complexo, limitando o processamento a reduplicação de frames (duplicação bruta) e minimizando o tempo na fila (*queue*). | REQ-VID-SPD-011 |