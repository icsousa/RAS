# Pan&Crop
### Casos de Uso · Fase 1: Suporte a Vídeo no PictuRAS

---

## 0. Identificação

| **Campo** | **Valor** |
|-----------|-----------|
| **Grupo / Equipa** | Grupo 1 |
| **Autores** | Duarte Pinto Bravo (*pg63951*), Ivo Costa Sousa (*pg63976*), Tiago Gonçalves de Melo (*pg65445*)|
| **Data** | 2026-10-05 |
| **Versão do documento** | v1.0 |
| **Unidade Curricular** | Requisitos e Arquiteturas de Software — MEI, Universidade do Minho |

---

## 1. Funcionalidade de vídeo escolhida

| **Campo** | **Valor** |
|-----------|-----------|
| **Funcionalidade** | Enquadramento dinâmico com keyframes (*Pan & Crop*) |
| **Perfil(s) de utilizador abrangido(s)** | Registado e Premium. Por se tratar de uma operação computacionalmente intensiva que exige transcodificação e interpolação contínua de fotogramas, restringe-se a utilizadores autenticados, aplicando limites no número de keyframes para perfis registados. |

**Justificação no contexto do MVP**
O enquadramento dinâmico introduz no PictuRAS a capacidade de transformação espacial ao longo da linha temporal, indispensável para reformatar vídeos para diferentes rácios de aspeto (como a conversão de 16:9 horizontal para 9:16 vertical nas redes sociais). Valida o pipeline de renderização com recurso a filtros dinâmicos de corte e escala, garantindo que o sistema consegue recalcular coordenadas espaciais frame a frame sem dessincronizar com o áudio. Sem esta funcionalidade, o PictuRAS fica limitado a edições estáticas, não permitindo focar pontos de interesse em movimento.

---

## 2. Caso de Uso

### 2.1 Cabeçalho

| **Secção** | **Detalhes** |
|------------|--------------|
| **ID do Caso de Uso** | UC-VID-002 |
| **Nome** | Enquadramento dinâmico com keyframes (*Pan & Crop*) |
| **Versão** | v1.0 |
| **Autor** | Ivo Sousa & Tiago Melo |
| **Data** | 2026-10-05 |
| **Objetivo** | Aplicar efeitos contínuos de zoom e deslocamento espacial através da definição de áreas de corte associadas a pontos temporais específicos (keyframes). |
| **Âmbito** | Módulo de Edição Multimédia / Pipeline de Transformação de Vídeo do PictuRAS |
| **Ator Principal** | Utilizador Registado ou Premium |
| **Stakeholders e Interesses** | - **Utilizador**: Deseja criar movimentos suaves de câmara e focar áreas de interesse sem perder resolução desnecessariamente.<br>- **Operador da Infraestrutura**: Deseja mitigar picos de consumo de CPU/GPU estabelecendo limites no número de keyframes interpolados e na duração do vídeo.<br>- **Equipa de Produto PictuRAS**: Valorizar as contas Premium oferecendo interpolações avançadas e keyframes ilimitados. |
| **Pré-condições** | - Um vídeo suportado encontra-se carregado no editor PictuRAS.<br>- O utilizador está autenticado como Registado ou Premium com quota de operações disponível.<br>- As dimensões de resolução nativa do vídeo foram calculadas com sucesso pelo sistema. |
| **Trigger** | O utilizador seleciona a ferramenta "Pan & Crop" no painel de ferramentas de vídeo. |

### 2.2 Fluxo Principal

| **Passo** | **Ação do Ator** | **Resposta do Sistema** |
|-----------|------------------|-------------------------|
| 1 | O utilizador seleciona a ferramenta "Pan & Crop". | O sistema apresenta a interface de recorte com uma moldura de enquadramento sobreposta ao reprodutor, uma linha temporal com trilho dedicado a keyframes e controlos de rácio de aspeto. |
| 2 | O utilizador posiciona o cursor temporal no instante pretendido e ajusta a posição e dimensão da moldura de corte. | O sistema valida as dimensões mínimas da moldura, gera um novo *keyframe* nesse instante e atualiza a pré-visualização. |
| 3 | O utilizador desloca o cursor para outro instante temporal e redimensiona/desloca a moldura de corte para uma nova área. | O sistema regista o segundo *keyframe*, calcula a curva de interpolação linear entre ambos e indica visualmente o trajeto do movimento no trilho da timeline. |
| 4 | O utilizador solicita a pré-visualização da animação. | O sistema simula a transição contínua de escala e posição entre os keyframes definidos ao longo da reprodução. |
| 5 | O utilizador confirma a aplicação do enquadramento. | O sistema valida a quota do utilizador, bloqueia a interface contra novas alterações e envia a tarefa de processamento para a fila de renderização. |
| 6 | — | O serviço de vídeo processa a transformação espacial contínua fotograma a fotograma através da pipeline de filtros de vídeo. |
| 7 | — | O sistema guarda o vídeo final resultante no projeto, debita a operação da quota do utilizador e desbloqueia a interface exibindo o resultado. |

### 2.3 Fluxos Alternativos

| **Fluxo** | **Descrição** |
|-----------|---------------|
| FA1 – Edição ou Remoção de Keyframe | No Passo 3, o utilizador pode selecionar um *keyframe* pré-existente na timeline para ajustar as suas coordenadas espaciais ou removê-lo. O sistema recalcula automaticamente a interpolação entre os keyframes vizinhos que restarem. |
| FA2 – Fixação de Rácio de Aspeto Fixo (Aspect Ratio Lock) | No Passo 2, o utilizador ativa uma proporção fixa (ex.: 1:1, 9:16, 16:9). O sistema força a caixa delimitadora a manter a proporção escolhida durante todas as ações de redimensionamento e deslocamento. |

### 2.4 Exceções

| **Condição** | **Comportamento do Sistema** |
|--------------|------------------------------|
| Dimensão de corte inferior à resolução mínima suportada (< 320x240) | Se o utilizador tentar reduzir a caixa de enquadramento abaixo do limite mínimo de resolução, o sistema bloqueia a redução adicional, emite a notificação "A área de corte não pode ser inferior a 320x240 píxeis para evitar pixelização excessiva" e mantém a última dimensão válida. |
| Número de keyframes excede o limite do perfil de utilizador | Se um utilizador com perfil Registado tentar adicionar um keyframe para além do limite máximo permitido por regra de negócio, o sistema bloqueia a criação do ponto, apresenta uma notificação sobre o teto do plano e sugere a subscrição de conta Premium. |
| Erro de alocação de memória na pipeline de transcodificação de filtros de vídeo | Se o nó de processamento esgotar a memória durante o cálculo dos filtros espaciais ao longo do tempo, a tarefa é interrompida. O sistema notifica o utilizador com "Falha de processamento por falta de recursos no nó de renderização", preserva o vídeo original e não debita a quota da conta. |

### 2.5 Pós-condições

| **Tipo** | **Resultado** |
|----------|---------------|
| Garantia de Sucesso | É gerado um novo vídeo com as transformações de zoom e enquadramento interpoladas suavemente de acordo com os keyframes; a taxa de fotogramas e o áudio mantêm-se íntegros; a operação é debitada na quota do utilizador. |
| Garantia Mínima | O ficheiro de vídeo original permanece inalterado; quaisquer dados temporários de renderização são eliminados; a quota de operações do utilizador não é debitada. |

### 2.6 Regras de Negócio e Restrições

| **ID** | **Regra** |
|--------|-----------|
| RN1 | Limite de keyframes por perfil: Utilizadores Registados podem definir no máximo 5 keyframes por vídeo; Utilizadores Premium têm suporte para keyframes ilimitados. |
| RN2 | Resolução mínima de recorte: Nenhuma janela de corte em qualquer keyframe pode ter dimensões inferiores a 320x240 píxeis. |
| RN3 | Restrição de perfil: A funcionalidade de *Pan & Crop* requer autenticação prévia, não se encontrando disponível para o perfil de utilizador Anónimo devido ao custo de processamento associado. |
| RN4 | Consumo de quota: Uma operação de *Pan & Crop* concluída com sucesso debita 1 crédito diário da quota de vídeo da conta. |

### 2.7 Assunções

| **ID** | **Assunção** |
|--------|--------------|
| A1 | O serviço de vídeo dispõe de capacidade de aceleração gráfica (GPU) ou bibliotecas de processamento multimédia com suporte a filtros de transformação afim em lote (*batch*). |
| A2 | A interface do cliente tem capacidade para calcular e renderizar a pré-visualização em tempo real das matrizes de transformação 2D antes da renderização final no servidor. |
| A3 | O rácio de amostragem de fotogramas original (FPS) do vídeo de entrada mantém-se estável para garantir a linearidade temporal da interpolação. |

### 2.8 Questões em Aberto

| **ID** | **Questão** |
|--------|-------------|
| Q1 | A curva de interpolação deve limitar-se a uma transição linear ou deve ser disponibilizada aceleração e desaceleração suave (*ease-in / ease-out*) na versão base? |
| Q2 | Se o vídeo final resultante do *crop* mantiver as dimensões originais do ficheiro de entrada através de *upscaling*, que algoritmo de interpolação (bilinear, bicúbico ou lanczos) deve ser aplicado por omissão? |

---

## 3. Utilização de agentes de IA

| **Ferramenta / *skill*** | **Tarefa apoiada** | **Validação realizada pela equipa** |
|--------------------------|--------------------|--------------------------------------|
| Google Gemini | Modelação dos passos de interação com keyframes, formulação de fluxos alternativos de rácio fixo e delimitação das restrições de resolução mínima e consumo de recursos. | Revisão e validação integral pela equipa: verificação da consistência das restrições por perfil (exclusão de anónimos por custo de GPU), calibração do número razoável de keyframes e validação dos critérios de falha de renderização. |

---

## 4. Especificação de Requisitos do Sistema (ERS)

**Caso de Uso:** UC-VID-002 — Enquadramento dinâmico com keyframes (*Pan & Crop*)  
**Versão do dossiê:** v1.1  
**Baseline do Exercício 1:** v1.0 (Requisitos originais REQ-VID-CROP-001 a REQ-VID-CROP-010)

### 4.1 Requisitos da ERS

#### 4.1.1 Requisitos Funcionais

| **ID** | **Requisito** | **Prioridade** | **Evolução** | **Novo/Alt** | **Origem (UC / RN / decisão)** | **Justificação** | **Critério de aceitação / verificação** |
|--------|---------------|----------------|--------------|--------------|--------------------------------|-----------------|----------------------------------------|
| REQ-VID-CROP-001 | O sistema deve disponibilizar uma interface gráfica com trilho de *keyframes* e moldura de enquadramento interativa no reprodutor. | Deve ter | Refinado | NOVO | Passo 1 | É a base da interação UI para manipulação espacial e temporal. | Dado que a ferramenta "Pan & Crop" está ativa, Quando o utilizador acede à área de trabalho, Então a linha temporal mostra um trilho próprio para keyframes e o reprodutor apresenta os delimitadores ajustáveis. |
| REQ-VID-CROP-002 | O sistema deve gravar instâncias de *keyframes* que associam o timestamp atual às coordenadas e dimensões exatas da moldura. | Deve ter | Refinado | NOVO | Passo 2, Passo 3 | Permite o mapeamento entre a dimensão temporal e as transformações espaciais. | Dado que o cursor temporal está num instante $T$, Quando a moldura é ajustada, Então um marcador visual é criado em $T$ armazenando as coordenadas $[x, y, w, h]$. |
| REQ-VID-CROP-003 | O sistema deve calcular dinamicamente os valores interpolados (translação e escala) para os fotogramas entre *keyframes* adjacentes. | Deve ter | Refinado | NOVO | Passo 3, FA1 | Essencial para gerar a ilusão de movimento contínuo da câmara virtual. | Dado um *keyframe* A e um *keyframe* B, Quando analisado qualquer frame intermédio, Então as suas coordenadas refletem uma progressão linear entre as propriedades de A e B. |
| REQ-VID-CROP-004 | O sistema deve aplicar as matrizes de transformação calculadas à janela de pré-visualização para simular o resultado em tempo real. | Deve ter | Refinado | NOVO | Passo 4 | O utilizador necessita de validar o percurso do enquadramento sem aguardar por renderização remota. | Dado um percurso demarcado, Quando o utilizador pressiona "Play" na pré-visualização, Então o canvas aproxima/afasta e desloca-se acompanhando o trajeto estipulado de forma fluída. |
| REQ-VID-CROP-005 | O sistema deve forçar a moldura a manter uma proporção geométrica predefinida (ex: 1:1, 16:9) caso o utilizador ative essa restrição. | Poderia ter | Refinado | NOVO | FA2 | Facilita a adaptação direta do vídeo para formatos específicos de redes sociais. | Dado o rácio fixo "1:1" ativado, Quando o utilizador arrasta a aresta lateral da moldura, Então a aresta superior ajusta-se automaticamente para formar um quadrado perfeito. |
| REQ-VID-CROP-006 | O sistema deve bloquear o encolhimento da área de corte a dimensões inferiores a 320x240 píxeis, emitindo um alerta de limite. | Deve ter | Refinado | NOVO | Passo 2, E1, RN2 | Previne recortes microscópicos que resultariam num vídeo final inteiramente irreconhecível e pixelizado. | Dado que a moldura mede 320x240, Quando o utilizador tenta reduzir o tamanho, Então o cursor de redimensionamento é bloqueado e surge a mensagem "Área mínima atingida". |
| REQ-VID-CROP-007 | O sistema deve impor um limite de 5 *keyframes* ao perfil Registado e bloquear totalmente a entrada na ferramenta a perfis Anónimos. | Deve ter | Refinado | NOVO | E2, RN1, RN3 | Protege a infraestrutura limitando o uso de ferramentas CPU-intensivas a escalões autenticados ou pagos. | Dado um utilizador anónimo, Quando tenta abrir a ferramenta "Pan & Crop", Então a UI bloqueia o acesso e sugere autenticação/criação de conta. |
| REQ-VID-CROP-010 | O sistema deve deduzir exatamente 1 crédito à quota diária do utilizador assim que o vídeo resultante for guardado com sucesso. | Deve ter | Refinado | ALT | Passo 7, RN4 | Mantém o modelo de monetização coerente através da plataforma. | Dado um utilizador com 10 créditos, Quando a operação processa totalmente e guarda o ficheiro, Então o saldo consultado passa a 9 créditos. |
| REQ-VID-CROP-011 | O sistema deve apresentar um indicador de progresso (estado da fila e percentagem de renderização) durante a exportação do ficheiro. | Deve ter | Novo | NOVO | Passo 6, Secção 4.1.3 | O cálculo fotograma a fotograma da transformação afim é demorado, exigindo comunicação de estado para evitar que o utilizador abandone a página. | Dado o bloqueio da interface após confirmação, Quando a *queue* avança, Então a UI atualiza uma barra de carregamento com a evolução do processamento no servidor. |

#### 4.1.2 Requisitos Não Funcionais e de Qualidade

| **ID** | **Requisito** | **Característica ISO/IEC 25010** | **Alvo MVP** | **Alvo produção** | **Evolução** | **Origem (UC / DQ)** | **Critério de aceitação / verificação** |
|--------|---------------|----------------------------------|--------------|------------------|--------------|----------------------|----------------------------------------|
| REQ-VID-CROP-008 | O processamento do enquadramento dinâmico deve manter intacta a taxa de fotogramas (FPS) nativa e evitar perdas ou desfasamentos na faixa de áudio. | Fiabilidade (Integridade de processamento) | Manutenção de FPS e de sincronismo absoluto | Idem | Refinado | Passo 6, Garantia de Sucesso | Dado um clipe a 60fps com áudio sincronizado, Quando sujeito a *Pan & Crop*, Então o *output* preserva os exatos 60fps originais e o *lipsync* permanece inalterado. |
| REQ-VID-CROP-009 | O sistema deve tolerar falhas de falta de memória (OOM) no *worker*, abortando a transcodificação de forma controlada sem gravar artefactos corrompidos. | Fiabilidade (Tolerância a Falhas) | Interrupção segura do job, UI notificada | Recuperação automática / retry em *worker* com mais RAM | Refinado | E3, Garantia Mínima, DQ-002 | Dado o esgotamento de VRAM/RAM a meio do render, Quando o processo FFmpeg aborta, Então a API trata a exceção, o vídeo base não é substituído e o utilizador é avisado sem perder créditos. |
| REQ-VID-CROP-012 | A interpolação e extração de vídeo deve ser processada com eficiência utilizando um algoritmo que evite bloqueios monopolizadores de CPU na infraestrutura. | Eficiência de Desempenho (Utilização de Recursos) | Interpolação bilinear (foco no desempenho) | Interpolação bicúbica/Lanczos com aceleração via GPU | Novo | Secção 4.1.3, DQ-001 | Dado o envio de um *job* de crop com zoom dinâmico, Quando o sistema renderiza os fotogramas, Então utiliza por omissão o filtro de interpolação bilinear definido para minimizar o custo por ciclo de CPU. |

#### 4.1.3 Verificação da completude e dos limites do âmbito

| **Tópico a verificar** | **Aplicável?** | **Decisão / justificação** | **Requisito(s) relacionado(s)** |
|-----------------------|---------------|----------------------------|--------------------------------|
| Formato, codec, duração e dimensão do vídeo | Sim | O enquadramento dinâmico implica manipulação direta da matriz de píxeis e *upscaling*, sendo fortemente condicionado por resoluções mínimas suportadas. | REQ-VID-CROP-006, REQ-VID-CROP-008 |
| Estado, progresso, cancelamento e resultado | Sim | Essencial, uma vez que a aplicação de filtros espaciais contínuos no tempo (ex: `zoompan`) exige recodificação total, o que introduz latência percetível. | REQ-VID-CROP-009, REQ-VID-CROP-011 |
| Falhas durante o processamento | Sim | Picos de alocação de memória ao interpolar matrizes de transformação frame a frame são o principal ponto de estrangulamento que requer tratamento seguro. | REQ-VID-CROP-009 |
| Persistência e expiração dos ficheiros | Não | Regras de validade temporal e limpeza de cache são transversais à arquitetura *core* do armazenamento e fogem à lógica estrita do recorte dinâmico. | N/A |
| Perfis e contagem de operações | Sim | O forte custo de processamento exige que a funcionalidade interdite utilizadores Anónimos, aplique limites estritos de keyframes e desconte créditos. | REQ-VID-CROP-007, REQ-VID-CROP-010 |
| Encadeamento de ferramentas e processamento em lote | Não | O *Pan & Crop* atua como ferramenta primária aplicada de forma atómica e isolada por validação no contexto do MVP, não sendo embutida em *pipelines* de lote. | N/A |

### 4.2 Impacto no sistema existente

| **Elemento existente afetado** | **Impacto (Manter / Estender / Alterar)** | **Descrição do impacto** | **Requisito(s) relacionado(s)** |
|--------------------------------|-------------------------------------------|--------------------------|--------------------------------|
| Interface Gráfica (*Canvas* e *Cropper* atual) | Estender | A ferramenta de corte estática usada nas imagens tem de evoluir para suportar dimensões dinâmicas vinculadas aos carimbos temporais do vídeo e rastreamento de *keyframes* na timeline. | REQ-VID-CROP-001, REQ-VID-CROP-005 |
| Motor de pré-visualização (Cliente Web) | Estender | Integração de lógica de simulação fluída utilizando interpolação nativa (ex: CSS `transform: scale() translate()`) sobre o reprodutor HTML5 para evitar chamadas de renderização ao servidor durante a edição. | REQ-VID-CROP-003, REQ-VID-CROP-004 |
| Módulo de Controlo de Acessos (RBAC) e Quotas | Estender | Necessidade de inibir a funcionalidade aos utilizadores Anónimos e injetar lógicas na API para validar o tamanho do *payload* (limite estrito de 5 keyframes na submissão de contas Registadas). | REQ-VID-CROP-007, REQ-VID-CROP-010 |
| Fila assíncrona de processamento e *Workers* | Alterar | Os *workers* devem integrar filtros multimédia espaciotemporais (cadeia `scale` e `zoompan`) e implementar barreiras de salvaguarda contra picos de RAM/VRAM (*OOM killer bypass*). | REQ-VID-CROP-008, REQ-VID-CROP-009, REQ-VID-CROP-012 |

### 4.3 Matriz de Rastreabilidade Atualizada

| **Elemento de origem** | **Descrição abreviada** | **Requisito(s) relacionado(s)** |
|------------------------|-------------------------|--------------------------------|
| Passo 1 | Apresentação do canvas, timeline e controlo de enquadramento | REQ-VID-CROP-001 |
| Passo 2, Passo 3 | Rastreamento temporal de *keyframes* com coordenadas $[x,y,w,h]$ | REQ-VID-CROP-002 |
| Passo 3, FA1 | Algoritmo de cálculo interpolado das matrizes de transformação | REQ-VID-CROP-003 |
| Passo 4 | Pré-renderização leve baseada em propriedades frontend | REQ-VID-CROP-004 |
| FA2 | Fixação geométrica e forçamento de rácio (16:9, etc.) | REQ-VID-CROP-005 |
| E1, RN2 | Proteção contra ampliação destrutiva de baixa resolução (<320x240px) | REQ-VID-CROP-006 |
| E2, RN1, RN3 | Escalões de serviço: interdição a anónimos e tetos de marcadores | REQ-VID-CROP-007 |
| E3, Garantia Mínima, DQ-002 | Salvaguarda anti-OOM para abortar e proteger o worker | REQ-VID-CROP-009 |
| Garantia Sucesso, Passo 6 | Processamento integral preservando sincronismo e framerate | REQ-VID-CROP-008 |
| Passo 7, RN4 | Registo da operação na contabilidade da carteira diária | REQ-VID-CROP-010 |
| Secção 4.1.3, Passo 6/7 | Necessidade de visibilidade e progresso de fila na UI | REQ-VID-CROP-011 |
| DQ-001 | Escolha algorítmica face à sobrecarga de CPU no MVP | REQ-VID-CROP-012 |

**Decisões de qualidade introduzidas nesta aula**

| **ID** | **Decisão de qualidade** | **Justificação** | **Requisito(s) relacionado(s)** |
|--------|--------------------------|-----------------|--------------------------------|
| DQ-001 | Adoção de interpolação bilinear padrão para o recálculo fotograma a fotograma no MVP. | O reescalonamento dinâmico com algoritmos complexos (bicúbico, Lanczos) consome recursos excessivos na ausência de clusters GPU massivos. O método bilinear garante tempos de fila aceitáveis para todos os perfis. | REQ-VID-CROP-012 |
| DQ-002 | Privilegiar a falha rápida e limpa em caso de pico de memória (*Out Of Memory*). | Renderizações como o `zoompan` podem forçar o nó a paginar (usar disco em vez de RAM), o que paralisa o *worker*. Terminar a tarefa de imediato protege o nó e assegura disponibilidade do sistema. | REQ-VID-CROP-009 |