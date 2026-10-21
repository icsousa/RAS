# 📝 Exercício 1 
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
| **Funcionalidade** | Aplicação de filtros de cor (*Color Grading / LUTs*) |
| **Perfil(s) de utilizador abrangido(s)** | Anónimo, registado e premium. O ajuste cromático e a aplicação de filtros predefinidos é uma capacidade nuclear do PictuRAS que deve abranger todos os perfis, reservando-se a importação de tabelas de conversão tridimensionais personalizadas (LUTs `.cube`) e resoluções elevadas para contas pagas. |

**Justificação no contexto do MVP**
A gradação de cor estende diretamente o ecossistema existente de processamento fotográfico do PictuRAS para o domínio temporal do vídeo. Permite validar a capacidade da arquitetura em encadear operações matriciais de transformação de píxeis de forma massiva sobre sequências de fotogramas sem desfasamento do fluxo áudio. Sem esta funcionalidade, o PictuRAS não aproveita o seu motor de filtros já consolidado em imagem para potenciar o processamento de vídeo.

---

## 2. Caso de Uso

### 2.1 Cabeçalho

| **Secção** | **Detalhes** |
|------------|--------------|
| **ID do Caso de Uso** | UC-VID-005 |
| **Nome** | Aplicação de filtros de cor (*Color Grading / LUTs*) |
| **Versão** | v1.0 |
| **Autor** | Tiago Melo & Ivo Sousa  |
| **Data** | 2026-10-05 |
| **Objetivo** | Aplicar filtros de cor predefinidos, ajustes paramétricos (brilho, contraste, saturação) ou tabelas LUT 3D a todos os fotogramas de um vídeo. |
| **Âmbito** | Módulo de Edição Multimédia / Pipeline de Processamento Cromático do PictuRAS |
| **Ator Principal** | Utilizador (qualquer perfil de autenticação) |
| **Stakeholders e Interesses** | - **Utilizador**: Deseja harmonizar visualmente o vídeo ou conferir um estilo cromático específico com pré-visualização fidedigna.<br>- **Operador da Infraestrutura**: Garantir que as operações frame a frame utilizam aceleração gráfica (GPU) eficiente para não sobrecarregar a fila global de processamento.<br>- **Equipa de Produto PictuRAS**: Maximizar a reutilização dos algoritmos cromáticos existentes para imagem estática e diferenciar a oferta Premium através de LUTs customizados. |
| **Pré-condições** | - Um vídeo suportado encontra-se carregado e validado no editor PictuRAS.<br>- A interface gráfica carregou a biblioteca de predefinições de cor suportadas pelo sistema.<br>- O utilizador dispõe de saldo não nulo na sua quota diária de operações de vídeo. |
| **Trigger** | O utilizador seleciona a ferramenta "Filtros de Cor / Ajuste Cromático" no painel de edição de vídeo. |

### 2.2 Fluxo Principal

| **Passo** | **Ação do Ator** | **Resposta do Sistema** |
|-----------|------------------|-------------------------|
| 1 | O utilizador seleciona a ferramenta "Filtros de Cor". | O sistema exibe o painel de gradação com uma galeria de filtros predefinidos (ex.: Sépia, Alto Contraste, Preto & Branco, Cinematográfico), controlos paramétricos deslizantes (brilho, saturação, contraste) e um seletor de intensidade global (0 a 100%). |
| 2 | O utilizador seleciona um filtro predefinido e ajusta a barra de intensidade pretendida. | O sistema aplica a matriz cromática em tempo real sobre o fotograma atualmente pausado no reprodutor de vídeo para pré-visualização. |
| 3 | O utilizador solicita a reprodução do vídeo para avaliar o filtro dinamicamente. | O sistema reproduz o segmento do vídeo no reprodutor aplicando a transformação cromática via *shaders* no cliente. |
| 4 | O utilizador confirma a aplicação do filtro de cor. | O sistema bloqueia a interface de edição, valida a quota do utilizador e envia a instrução de processamento para a fila assíncrona de renderização de vídeo. |
| 5 | — | O serviço de vídeo processa a transformação cromática sobre a totalidade dos fotogramas da faixa de vídeo, mantendo intactos a taxa de fotogramas e o fluxo de áudio original. |
| 6 | — | O sistema atualiza o projeto com o novo vídeo processado, deduz uma operação na quota do utilizador e desbloqueia a interface com o resultado final. |

### 2.3 Fluxos Alternativos

| **Fluxo** | **Descrição** |
|-----------|---------------|
| FA1 – Importação de Tabela 3D LUT (.CUBE) | No Passo 2, se o utilizador possuir perfil Premium, seleciona "Importar LUT 3D" e submete um ficheiro `.cube`. O sistema valida a estrutura do ficheiro, calcula a matriz tridimensional e renderiza a pré-visualização sobre o vídeo antes da submissão no Passo 4. |
| FA2 – Ajuste Manual Sem Filtros Predefinidos | No Passo 2, o utilizador opta por não escolher um preset e ajusta manualmente os valores nos seletores de Brilho, Contraste, Saturação e Gama. O sistema concatena os filtros individuais numa única cadeia de processamento. |

### 2.4 Exceções

| **Condição** | **Comportamento do Sistema** |
|--------------|------------------------------|
| Ficheiro 3D LUT malformado ou corrompido | Se o utilizador submeter um ficheiro `.cube` com cabeçalhos incorretos, dimensões de grelha não suportadas (diferentes de 17x17x17, 33x33x33 ou 65x65x65) ou valores cromáticos fora da gama $[0.0, 1.0]$, o sistema recusa o ficheiro, emite o erro "Ficheiro LUT inválido ou corrompido" e repõe a visualização do vídeo sem alterações. |
| Esgotamento de memória gráfica (GPU/VRAM) durante a renderização de fotogramas em alta resolução | No Passo 5, se o nó de processamento esgotar os recursos de memória ao aplicar a matriz de cor em vídeos de resolução 4K ou superior, a tarefa é interrompida. O sistema notifica o utilizador com a mensagem "Falha temporária de processamento por falta de memória gráfica no nó de renderização", repõe o vídeo anterior e não debita a quota da conta. |
| Utilizador sem permissão a tentar carregar LUT personalizado | No Passo 2, se um utilizador Anónimo ou Registado tentar carregar um ficheiro `.cube`, o sistema bloqueia o envio do ficheiro, exibe uma mensagem informativa informando que a importação de LUTs 3D personalizados é uma funcionalidade exclusiva do perfil Premium e regressa à galeria de predefinições. |

### 2.5 Pós-condições

| **Tipo** | **Resultado** |
|----------|---------------|
| Garantia de Sucesso | Um novo ficheiro de vídeo com a gradação de cor e matriz cromática aplicada a todos os fotogramas é disponibilizado no projeto; o fluxo de áudio e a taxa de fotogramas permanecem inalterados; a operação é deduzida na quota do utilizador. |
| Garantia Mínima | O ficheiro de vídeo de entrada mantém-se inalterado; nenhum artefacto com frames incompletos ou corrompidos é guardado; a quota de operações do utilizador não sofre qualquer débito. |

### 2.6 Regras de Negócio e Restrições

| **ID** | **Regra** |
|--------|-----------|
| RN1 | Suporte a LUTs personalizados: O carregamento e aplicação de ficheiros de tabelas 3D LUT (`.cube`) é restrito exclusivamente ao perfil de utilizador Premium. |
| RN2 | Resolução máxima permitida para gradação de cor: Utilizadores Anónimos até 720p; Registados até 1080p; Premium até 4K. |
| RN3 | Preservação audiovisual: A aplicação de filtros de cor afeta unicamente a informação do fluxo de vídeo, não devendo reamostrar, alterar ou dessincronizar o fluxo de áudio existente. |
| RN4 | Consumo de quota: Uma operação de aplicação de filtros de cor concluída com sucesso consome 1 crédito diário da quota de vídeo da conta. |

### 2.7 Assunções

| **ID** | **Assunção** |
|--------|--------------|
| A1 | Os nós do serviço de processamento multimédia do PictuRAS possuem aceleração por hardware ou bibliotecas com filtros otimizados (`lut3d`, `eq`, `colorbalance`) com capacidade de processamento concorrente. |
| A2 | O cliente web possui suporte para a API WebGL para conseguir renderizar *shaders* de correção cromática em tempo real no elemento `<video>` durante a pré-visualização. |
| A3 | O espaço de cor do vídeo de entrada encontra-se em normas padrão suportadas (ex.: Rec.709 ou sRGB), evitando distorções imprevistas na aplicação de predefinições de cor. |

### 2.8 Questões em Aberto

| **ID** | **Questão** |
|--------|-------------|
| Q1 | O sistema deve disponibilizar aplicação de filtros a trechos temporais delimitados ou a funcionalidade aplica-se invariavelmente à totalidade da linha temporal do vídeo? |
| Q2 | No caso de vídeos codificados com curvas logarítmicas (*Log Profiles* como S-Log ou D-Log), deve ser fornecido um passo intermédio de normalização de espaço de cor antes da aplicação dos LUTs criativos? |

---

## 3. Utilização de agentes de IA

| **Ferramenta / *skill*** | **Tarefa apoiada** | **Validação realizada pela equipa** |
|--------------------------|--------------------|--------------------------------------|
| Google Gemini | Modelação dos passos de aplicação matricial de cor, levantamento de exceções ligadas a tabelas LUT e limites de VRAM, e definição das regras de negócio por perfil. | Revisão manual rigorosa pela equipa: validação das restrições de formato `.cube`, calibração dos limites de resolução por perfil para salvaguarda de recursos e confirmação da invariância da faixa de áudio. |

---

## 4. Especificação de Requisitos do Sistema (ERS)

**Caso de Uso:** UC-VID-005 — Aplicação de filtros de cor (*Color Grading / LUTs*)[cite: 11]  
**Versão do dossiê:** v1.1  
**Baseline do Exercício 1:** v1.0 (Requisitos originais REQ-VID-COL-001 a REQ-VID-COL-009)[cite: 11]

### 4.1 Requisitos da ERS

#### 4.1.1 Requisitos Funcionais

| **ID** | **Requisito** | **Prioridade** | **Evolução** | **Novo/Alt** | **Origem (UC / RN / decisão)** | **Justificação** | **Critério de aceitação / verificação** |
|--------|---------------|----------------|--------------|--------------|--------------------------------|-----------------|----------------------------------------|
| REQ-VID-COL-001 | O sistema deve disponibilizar um painel de gradação com galeria de filtros predefinidos e controlos paramétricos de cor (brilho, contraste, saturação) na interface. | Deve ter | Refinado | ALT | Passo 1[cite: 11] | É a interface central que materializa o ajuste cromático. | Dado que a ferramenta de Cor é selecionada, Quando o painel carrega, Então o utilizador visualiza opções predefinidas e barras de ajuste de intensidade de 0 a 100%. |
| REQ-VID-COL-002 | O sistema deve renderizar em tempo real a transformação cromática no cliente durante a edição, utilizando aceleração de *shaders* web. | Deve ter | Refinado | NOVO | Passo 2, Passo 3[cite: 11] | Garante a fluidez do processo criativo ao dar *feedback* imediato sem depender do processamento remoto. | Dado o ajuste manual da barra de contraste, Quando deslizada, Então o fotograma exibido na pré-visualização reflete instantaneamente a alteração. |
| REQ-VID-COL-003 | O sistema deve permitir a concatenação de múltiplos ajustes paramétricos individuais de imagem numa cadeia de processamento única. | Deve ter | Refinado | NOVO | FA2[cite: 11] | Dá flexibilidade para o utilizador compor filtros manuais quando os predefinidos não satisfazem. | Dado que o utilizador alterou o Brilho e a Saturação, Quando o vídeo é pré-visualizado/exportado, Então ambos os efeitos são aplicados sobre os mesmos píxeis. |
| REQ-VID-COL-004 | O sistema deve bloquear a importação de tabelas 3D LUT (`.cube`) a contas Anónimas e Registadas, reservando a funcionalidade para o perfil Premium. | Deve ter | Refinado | NOVO | FA1, E3, RN1[cite: 11] | Cria diferenciação de valor para os utilizadores do nível pago. | Dado um utilizador Registado, Quando tenta enviar um ficheiro `.cube`, Então a interface bloqueia o envio informando tratar-se de recurso Premium. |
| REQ-VID-COL-005 | O sistema deve validar a integridade estrutural e dimensões padronizadas (17x17x17, 33x33x33 ou 65x65x65) do ficheiro LUT `.cube` submetido. | Deve ter | Refinado | NOVO | E1[cite: 11] | Ficheiros malformados causam falhas severas no motor de *render*. | Dado um ficheiro `.cube` inválido submetido por um utilizador Premium, Quando processado, Então o sistema aborta e emite notificação de formato corrompido. |
| REQ-VID-COL-006 | O sistema deve restringir a resolução máxima de processamento de acordo com o perfil (Anónimo ≤ 720p, Registado ≤ 1080p, Premium ≤ 4K). | Deve ter | Refinado | NOVO | RN2[cite: 11] | Limita os custos computacionais da plataforma face à escalabilidade do modelo de negócio. | Dado um utilizador Anónimo com um vídeo 1080p, Quando confirma o processamento, Então a resolução de *output* é automaticamente limitada ou a operação é rejeitada. |
| REQ-VID-COL-009 | O sistema deve deduzir exatamente 1 crédito à quota diária do utilizador assim que a transcodificação final de cor for gravada com sucesso. | Deve ter | Refinado | ALT | Passo 6, RN4[cite: 11] | Mantém o modelo transacional de consumo do PictuRAS de forma unificada. | Dado um saldo atual de créditos, Quando o *color grading* conclui o *render* e guarda, Então o saldo na base de dados é subtraído em uma unidade. |
| REQ-VID-COL-010 | O sistema deve notificar o utilizador sobre o estado do processamento assíncrono durante a renderização do vídeo. | Deve ter | Novo | NOVO | Passo 5, Passo 6[cite: 11], Secção 4.1.3 | A aplicação de uma matriz de cor a todos os píxeis de todos os fotogramas consome tempo, requerendo clarificação de estado da fila. | Dado o clique em confirmar, Quando a tarefa é enviada para o servidor, Então a UI do cliente exibe o progresso contínuo (percentagem/estado da *queue*). |

#### 4.1.2 Requisitos Não Funcionais e de Qualidade

| **ID** | **Requisito** | **Característica ISO/IEC 25010** | **Alvo MVP** | **Alvo produção** | **Evolução** | **Origem (UC / DQ)** | **Critério de aceitação / verificação** |
|--------|---------------|----------------------------------|--------------|------------------|--------------|----------------------|----------------------------------------|
| REQ-VID-COL-007 | O processamento não deve interferir ou reamostrar a faixa de áudio e deve manter exata a taxa de fotogramas (FPS) original do vídeo. | Fiabilidade (Integridade de processamento) | Pass-through inalterado do codec de áudio | Idem | Refinado | Passo 5, RN3[cite: 11], DQ-002 | Dado o ficheiro final, Quando inspecionado via medição de *media info*, Então o codec áudio original e o FPS mantêm-se estritamente iguais à fonte. |
| REQ-VID-COL-008 | O sistema deve tolerar esgotamento de memória VRAM (OOM) no *worker* gráfico, abortando a tarefa e repondo a versão segura sem cobrar quota. | Fiabilidade (Tolerância a Falhas) | *Fail-fast* limpo com alerta no cliente | Alocação dinâmica de nó suplementar | Refinado | E2[cite: 11], Garantia Mínima[cite: 11], DQ-003 | Dado um pico de consumo de RAM do GPU num vídeo 4K, Quando a transcoficação falha, Então a infraestrutura mata o processo seguro e não altera os ficheiros base. |
| REQ-VID-COL-011 | O método de *preview* no cliente web deve ter latência impercetível, garantindo uma resposta suave aos controlos paramétricos. | Eficiência de Desempenho (Comportamento Temporal) | Pré-visualização a ≥ 24fps baseada em WebGL | Idem | Novo | Passo 2[cite: 11], DQ-001 | Dado o ajuste contínuo de um controlo deslizante, Quando manipulado ativamente, Então a interface do vídeo atualiza a imagem mantendo um mínimo de 24 *frames* por segundo (*smooth preview*). |

#### 4.1.3 Verificação da completude e dos limites do âmbito

| **Tópico a verificar** | **Aplicável?** | **Decisão / justificação** | **Requisito(s) relacionado(s)** |
|-----------------------|---------------|----------------------------|--------------------------------|
| Formato, codec, duração e dimensão do vídeo | Sim | Estreitamente ligado ao consumo de memória. Aplicação a 4K, 1080p ou 720p exige limites definidos e restrições no formato `.cube`. | REQ-VID-COL-005, REQ-VID-COL-006 |
| Estado, progresso, cancelamento e resultado | Sim | Essencial, porque aplicar o filtro a um vídeo completo em servidor demora consoante a duração do clipe. | REQ-VID-COL-010 |
| Falhas durante o processamento | Sim | VRAM OOM é a principal causa de quebra na renderização de correções de cor fotograma a fotograma. | REQ-VID-COL-008 |
| Persistência e expiração dos ficheiros | Não | Regras de limpeza de vídeo intermédio pertencem à fundação do projeto, não à funcionalidade em si. | N/A |
| Perfis e contagem de operações | Sim | A tabela estipula monetização (Premium importa LUT 3D) e contenção de processamento (resolução máxima baseada no plano). | REQ-VID-COL-004, REQ-VID-COL-006, REQ-VID-COL-009 |
| Encadeamento de ferramentas e processamento em lote | Não | Funcionalidade validada numa interação atómica para o MVP de vídeo. | N/A |

### 4.2 Impacto no sistema existente

| **Elemento existente afetado** | **Impacto (Manter / Estender / Alterar)** | **Descrição do impacto** | **Requisito(s) relacionado(s)** |
|--------------------------------|-------------------------------------------|--------------------------|--------------------------------|
| UI de Filtros e Motor de Pré-visualização (*Client Web*) | Estender | O gestor de filtros já desenhado para imagens precisa suportar renderização dinâmica via API WebGL sobre o elemento de `<video>` HTML5, evitando bloqueios na *thread* principal[cite: 11]. | REQ-VID-COL-001, REQ-VID-COL-002, REQ-VID-COL-011 |
| *Workers* e Fila de Processamento Assíncrona | Alterar | Os serviços de *backend* terão de incorporar cadeias de processamento de cor em *batch* (`lut3d` e `colorbalance` do FFmpeg) recorrendo preferencialmente a instâncias com aceleração de hardware[cite: 11]. | REQ-VID-COL-003, REQ-VID-COL-007, REQ-VID-COL-008 |
| Controlo de Acesso e Módulo de Quotas (API) | Estender | A injeção de novas regras de negócio obrigam a API a recusar o processamento ou upload de `.cube` se o perfil de conta for inferior a Premium, além de impor tetos de resolução. | REQ-VID-COL-004, REQ-VID-COL-006, REQ-VID-COL-009 |

### 4.3 Matriz de Rastreabilidade Atualizada

| **Elemento de origem** | **Descrição abreviada** | **Requisito(s) relacionado(s)** |
|------------------------|-------------------------|--------------------------------|
| Passo 1 | UI de controlo, catálogos predefinidos e intensidade[cite: 11] | REQ-VID-COL-001 |
| Passo 2, Passo 3 | Pré-visualização WYSIWYG reativa via *shaders* Web[cite: 11] | REQ-VID-COL-002, REQ-VID-COL-011 |
| FA2 | Motor que funde parâmetros manuais independentes[cite: 11] | REQ-VID-COL-003 |
| FA1, E3, RN1 | Gestão de perfis restrita a LUTs customizados[cite: 11] | REQ-VID-COL-004 |
| E1 | Higienização estrita de formatação em LUT 3D `.cube`[cite: 11] | REQ-VID-COL-005 |
| RN2 | Defesa de infraestrutura mitigando limites de resolução[cite: 11] | REQ-VID-COL-006 |
| Passo 5, RN3, DQ-002 | Transcodificação fotográfica invaríante do áudio original[cite: 11] | REQ-VID-COL-007 |
| E2, Garantia Mínima, DQ-003 | Robustez do serviço impedindo ficheiros corrompidos em falhas de GPU[cite: 11] | REQ-VID-COL-008 |
| Passo 6, RN4 | Conclusão contabilizada com regra estandardizada[cite: 11] | REQ-VID-COL-009 |
| Secção 4.1.3, Passo 5/6 | Monitorização de atividade assíncrona remota no cliente | REQ-VID-COL-010 |

**Decisões de qualidade introduzidas nesta aula**

| **ID** | **Decisão de qualidade** | **Justificação** | **Requisito(s) relacionado(s)** |
|--------|--------------------------|-----------------|--------------------------------|
| DQ-001 | Delegação da pré-visualização cromática unicamente ao processador cliente (WebGL local). | Enviar pedidos de renderização de cor constantes ao servidor para o utilizador ajustar barras paramétricas inviabiliza o serviço em termos de custos. O WebGL faz este *offload* localmente. | REQ-VID-COL-011 |
| DQ-002 | Uso sistemático de "cópia de *stream* de áudio" (*Audio Pass-through*) no pipeline. | Um vídeo focado puramente em coloração não precisa recodificar (*re-encoding*) o som. Fazer a cópia exata previne desfasamento lábio e diminui carga no CPU dos *workers*. | REQ-VID-COL-007 |
| DQ-003 | Aborto seguro e rápido de transcodificações sob stress excessivo de memória VRAM (falha rápida). | Em ambientes *cloud* com aceleração GPU, um vídeo 4K sem memória suficiente entra em *swap* insuportável. Encerrar imediatamente a operação evita estrangulamentos a outros *jobs*. | REQ-VID-COL-008 |