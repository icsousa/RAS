# 📝 Trim
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
| **Funcionalidade** | Recorte temporal de vídeo (*trim*) |
| **Perfil(s) de utilizador abrangido(s)** | Anónimo, registado e premium. O recorte temporal é uma ferramenta elementar de edição que deve estar disponível para todos os perfis, diferenciando-se pelas restrições de duração máxima do ficheiro e quotas diárias de processamento. |

**Justificação no contexto do MVP**
O recorte temporal é a operação fundacional de edição de vídeo, análoga ao recorte espacial em imagem estática. Permite validar a arquitetura de desmultiplexagem, sincronização áudio/vídeo e persistência de segmentos sem exigir processamento intensivo de todos os fotogramas. Sem esta funcionalidade, o utilizador não consegue isolar excertos relevantes para aplicar as restantes ferramentas do sistema.

---

## 2. Caso de Uso

### 2.1 Cabeçalho

| **Secção** | **Detalhes** |
|------------|--------------|
| **ID do Caso de Uso** | UC-VID-001 |
| **Nome** | Recorte temporal de vídeo (*trim*) |
| **Versão** | v1.0 |
| **Autor** | Ivo Sousa & Tiago Melo |
| **Data** | 2026-10-05 |
| **Objetivo** | Isolar e extrair um segmento temporal contínuo de um ficheiro de vídeo através da seleção de pontos de início e fim. |
| **Âmbito** | Módulo de Edição Multimédia / Pipeline de Vídeo do PictuRAS |
| **Ator Principal** | Utilizador (qualquer perfil de autenticação) |
| **Stakeholders e Interesses** | - **Utilizador**: Deseja extrair um excerto temporal específico do vídeo com precisão e rapidez, preservando o sincronismo audiovisual.<br>- **Operador da Infraestrutura**: Deseja minimizar o consumo de recursos computacionais através da cópia direta de fluxos (*stream copy*) sem transcodificação completa quando viável.<br>- **Equipa de Produto PictuRAS**: Garantir a aplicação consistente dos limites e quotas definidos para cada perfil de utilizador. |
| **Pré-condições** | - Um ficheiro de vídeo suportado encontra-se carregado e validado no editor PictuRAS.<br>- O sistema extraiu os metadados do vídeo (duração, resolução, taxa de fotogramas e mapa de *keyframes*).<br>- O utilizador dispõe de quota de operações diárias não esgotada. |
| **Trigger** | O utilizador seleciona a ferramenta "Recorte Temporal" no painel de ferramentas de vídeo. |

### 2.2 Fluxo Principal

| **Passo** | **Ação do Ator** | **Resposta do Sistema** |
|-----------|------------------|-------------------------|
| 1 | O utilizador aciona a ferramenta de recorte temporal. | O sistema apresenta os controlos de corte na timeline com dois delimitadores interativos de início ($t_{\text{in}}$) e fim ($t_{\text{out}}$) e campos numéricos para introdução direta de tempo. |
| 2 | O utilizador ajusta as marcas $t_{\text{in}}$ e $t_{\text{out}}$ na timeline ou insere os valores nos campos numéricos. | O sistema valida os limites inseridos, atualiza a pré-visualização do fotograma de corte em tempo real e calcula a duração útil do excerto resultante. |
| 3 | O utilizador solicita a pré-visualização do segmento selecionado. | O sistema reproduz o segmento delimitado na janela do reprodutor. |
| 4 | O utilizador confirma a operação de recorte. | O sistema valida as quotas do perfil, bloqueia a interface de edição e despacha a tarefa de recorte para a fila de processamento assíncrono. |
| 5 | — | O serviço de processamento executa a extração do intervalo audiovisual selecionado, preservando a sincronização entre faixas. |
| 6 | — | O sistema disponibiliza o vídeo resultante no espaço de trabalho do projeto, atualiza o histórico de operações, debita uma unidade na quota do utilizador e restaura o controlo da interface. |

### 2.3 Fluxos Alternativos

| **Fluxo** | **Descrição** |
|-----------|---------------|
| FA1 – Corte Rápido em *Keyframes* (*Stream Copy*) | No Passo 2, se o utilizador ativar a opção "Corte Rápido", o sistema ajusta automaticamente $t_{\text{in}}$ e $t_{\text{out}}$ para os *keyframes* (I-frames) imediatamente adjacentes. No Passo 5, a extração é efetuada sem recodificação de vídeo (*codec copy*), diminuindo o tempo de processamento. |
| FA2 – Cancelamento da Operação | Em qualquer momento antes da confirmação no Passo 4, o utilizador clica em "Cancelar". O sistema descarta a seleção de marcadores temporais e restaura o vídeo ao estado inicial. |

### 2.4 Exceções

| **Condição** | **Comportamento do Sistema** |
|--------------|------------------------------|
| Marcadores temporais inconsistentes ($t_{\text{in}} \ge t_{\text{out}}$ ou duração < 0.5 s) | O sistema impede a confirmação no Passo 4, destaca os campos numéricos a vermelho, exibe uma mensagem informativa a indicar que o instante de término deve ser superior ao de início e mantém o utilizador no Passo 2. |
| Duração do excerto excede o limite do perfil | Se o intervalo temporal selecionado for superior ao limite estabelecido para a tipologia da conta (ex.: > 60 s para utilizador anónimo), o sistema bloqueia o avanço, apresenta notificação com a restrição de plano aplicável e convida ao registo ou atualização da conta. O vídeo original permanece intacto. |
| Falha de sincronismo ou fluxo de vídeo corrompido durante a extração | No Passo 5, caso o decodificador detete corrupção de fotogramas ou perda irrecuperável de alinhamento áudio/vídeo, a operação é abortada. O sistema notifica o utilizador da impossibilidade de processar o corte por anomalia no ficheiro, não debita a quota diária e repõe a visualização do vídeo pré-existente. |

### 2.5 Pós-condições

| **Tipo** | **Resultado** |
|----------|---------------|
| Garantia de Sucesso | Um novo ficheiro de vídeo recortado com duração correspondente a $t_{\text{out}} - t_{\text{in}}$ fica disponível no projeto; os fluxos de áudio e vídeo mantêm-se sincronizados; a operação é deduzida na quota do utilizador. |
| Garantia Mínima | O ficheiro original mantém-se inalterado e desimpedido; nenhum ficheiro corrompido é gravado no projeto; a quota de operações do utilizador não sofre qualquer débito. |

### 2.6 Regras de Negócio e Restrições

| **ID** | **Regra** |
|--------|-----------|
| RN1 | Limite de duração de recorte por perfil: Anónimo ≤ 60 segundos; Registado ≤ 300 segundos; Premium ≤ 3600 segundos. |
| RN2 | Duração mínima absoluta de um segmento recortado fixada em 0.5 segundos. |
| RN3 | Precisão de corte: no modo com re-encoding a precisão deve ser ao fotograma (*frame-accurate*); no modo rápido sem perdas o corte é circunscrito aos limites de *keyframe*. |
| RN4 | Consumo de quota: cada operação de recorte concluída com sucesso debita 1 crédito diário da quota de vídeo da conta. |

### 2.7 Assunções

| **ID** | **Assunção** |
|--------|--------------|
| A1 | O serviço de processamento multimédia do PictuRAS tem acesso direto por sistema de ficheiros ou armazenamento partilhado ao vídeo original carregado. |
| A2 | Os ficheiros de vídeo contêm tabela de metadados íntegra para identificação expedita das posições dos fotogramas-chave (*I-frames*). |
| A3 | O navegador do cliente suporta a reprodução HTML5 dos formatos e codecs padrão gerados (MP4/H.264/AAC) para pré-visualização. |

### 2.8 Questões em Aberto

| **ID** | **Questão** |
|--------|-------------|
| Q1 | O corte rápido em *keyframe* deve constituir a predefinição com transição automática para re-encoding, ou o utilizador deve escolher expressamente o modo? |
| Q2 | O artefacto recortado deve sobrepor-se ao vídeo na sessão atual ou gerar uma versão derivada preservando o nó anterior para reversão direta? |

---

## 3. Utilização de agentes de IA

| **Ferramenta / *skill*** | **Tarefa apoiada** | **Validação realizada pela equipa** |
|--------------------------|--------------------|--------------------------------------|
| Google Gemini | Apoio na estruturação inicial dos fluxos de corte temporal, levantamento de exceções específicas de dessincronização audiovisual e definição das regras de negócio por perfil de utilização. | Revisão manual completa pela equipa: adequação da terminologia técnica aos conceitos da UC (frames, keyframes, codecs), calibração das garantias pós-condição e ajuste das regras de quotas para não colidir com os limites já existentes do PictuRAS. |

---

## 4. Especificação de Requisitos do Sistema (ERS)

**Caso de Uso:** UC-VID-001 — Recorte temporal de vídeo (*trim*)  
**Versão do dossiê:** v1.1  
**Baseline do Exercício 1:** v1.0 (Requisitos originais REQ-VID-TRIM-001 a REQ-VID-TRIM-009)

### 4.1 Requisitos da ERS

#### 4.1.1 Requisitos Funcionais

| **ID** | **Requisito** | **Prioridade** | **Evolução** | **Novo/Alt** | **Origem (UC / RN / decisão)** | **Justificação** | **Critério de aceitação / verificação** |
|--------|---------------|----------------|--------------|--------------|--------------------------------|-----------------|----------------------------------------|
| REQ-VID-TRIM-001 | O sistema deve disponibilizar controlos interativos de seleção temporal ($t_{\text{in}}$ e $t_{\text{out}}$) na interface com precisão mínima ao milissegundo. | Deve ter | Refinado | NOVO | Passo 1, Passo 2 | Permite definir com exatidão o ponto de início e fim do recorte pretendido. | Dado que o vídeo está carregado, Quando o utilizador ajusta os marcadores na timeline ou introduz texto, Então os valores refletem-se no milissegundo exato. |
| REQ-VID-TRIM-002 | O sistema deve atualizar dinamicamente a pré-visualização do fotograma correspondente à posição atual dos marcadores $t_{\text{in}}$ e $t_{\text{out}}$. | Deve ter | Refinado | NOVO | Passo 2, Passo 3 | Feedback visual imediato é crítico para garantir um recorte preciso (ex: evitar cortar o meio de uma fala). | Dado os marcadores na timeline, Quando são movimentados pelo utilizador, Então o reprodutor atualiza instantaneamente o frame exibido. |
| REQ-VID-TRIM-004 | O sistema deve suportar extração sem recodificação (*stream copy*) alinhando os pontos de corte com os *keyframes* mais próximos. | Poderia ter | Refinado | NOVO | FA1, Passo 5, RN3 | Evita re-encoding pesado, poupando CPU no servidor e reduzindo tempos de espera. | Dado o modo de corte rápido ativo, Quando a operação termina, Então os codecs do contentor de saída são idênticos ao original (cópia de fluxo). |
| REQ-VID-TRIM-005 | O sistema deve impedir a confirmação da operação caso $t_{\text{in}} \ge t_{\text{out}}$ ou a duração útil seja inferior a 0.5 segundos. | Deve ter | Refinado | NOVO | E1, RN2 | Previne a submissão de jobs de processamento matematicamente inválidos ou impercetíveis. | Dado uma configuração onde $t_{\text{in}}$ é maior que $t_{\text{out}}$, Quando o utilizador tenta validar, Então a submissão é bloqueada e surge alerta. |
| REQ-VID-TRIM-006 | O sistema deve validar e aplicar limites estritos de duração máxima do excerto de acordo com o perfil autenticado (Anónimo: 60s, Registado: 300s, Premium: 3600s). | Deve ter | Refinado | NOVO | E2, RN1 | Assegura a viabilidade da infraestrutura e impõe o modelo freemium de negócio. | Dado um utilizador anónimo, Quando seleciona 65s de vídeo para cortar, Então o sistema bloqueia e sugere o registo/upgrade de plano. |
| REQ-VID-TRIM-007 | O sistema deve cancelar a operação, repor o ficheiro base e manter o saldo de quota em caso de falha no pipeline de processamento. | Deve ter | Refinado | NOVO | E3, Garantia Mínima | Previne a geração de artefactos corrompidos e evita consumir créditos do utilizador por erros de sistema. | Dado um erro interno no *worker* de vídeo, Quando o job aborta, Então a interface notifica falha, não deduz a quota diária e repõe a visualização original. |
| REQ-VID-TRIM-009 | O sistema deve debitar exatamente 1 crédito na quota diária de operações de vídeo do utilizador após conclusão bem-sucedida. | Deve ter | Refinado | ALT | Passo 6, RN4 | Aplica de forma coerente as lógicas de contabilização de quota introduzidas inicialmente pelas imagens. | Dado um saldo atual de N créditos, Quando um recorte termina com sucesso, Então o novo saldo atualizado reflete N-1. |
| REQ-VID-TRIM-010 | O sistema deve informar o estado e progresso da operação de extração (em fila, a processar, concluído). | Deve ter | Novo | NOVO | Passo 5, Passo 6, Secção 4.1.3 | Garante que o utilizador percebe que a operação assíncrona está a decorrer em background. | Dado o envio de um *job* para fila, Quando o *worker* atua, Então a interface bloqueada mostra o indicador atualizado do estado do processamento. |

#### 4.1.2 Requisitos Não Funcionais e de Qualidade

| **ID** | **Requisito** | **Característica ISO/IEC 25010** | **Alvo MVP** | **Alvo produção** | **Evolução** | **Origem (UC / DQ)** | **Critério de aceitação / verificação** |
|--------|---------------|----------------------------------|--------------|------------------|--------------|----------------------|----------------------------------------|
| REQ-VID-TRIM-003 | O sistema deve processar a extração sem introduzir desfasamento áudio/vídeo (*A/V desync*). | Fiabilidade (Maturidade / Adequação Funcional) | Desfasamento < 50 ms | Desfasamento < 20 ms | Refinado | Passo 5, DQ-001 | Dado o clip resultante com voz humana, Quando sujeito a medição instrumental, Então a discrepância entre frame visual e onda áudio cumpre a tolerância estabelecida. |
| REQ-VID-TRIM-008 | O processamento não deve degradar a taxa de fotogramas (FPS) nem a resolução espacial do vídeo original. | Fiabilidade (Integridade de processamento) | Mantém FPS e resolução exata | Mantém FPS, resolução e bitrate (target CQ) | Refinado | Garantia de Sucesso, Passo 6 | Dado um vídeo 1080p@60fps original, Quando sofre extração frame-accurate, Então os metadados do output preservam os exatos 1080p a 60fps. |
| REQ-VID-TRIM-011 | O modo de corte rápido (*stream copy*) deve extrair o segmento com elevada eficiência de desempenho, reduzindo tempos de bloqueio. | Eficiência de Desempenho (Comportamento temporal) | Tempo de extração < 10s (em excertos de até 100MB) | Tempo de extração < 5s (em excertos de até 500MB) | Novo | FA1, DQ-002 | Dado o trigger de corte rápido, Quando ativado para um limite suportado, Então o job reporta conclusão dentro da janela de tempo alvo. |

#### 4.1.3 Verificação da completude e dos limites do âmbito

| **Tópico a verificar** | **Aplicável?** | **Decisão / justificação** | **Requisito(s) relacionado(s)** |
|-----------------------|---------------|----------------------------|--------------------------------|
| Formato, codec, duração e dimensão do vídeo | Sim | Limites de duração são o core model de monetização (perfis). O processamento exige manutenção dos parâmetros originais para não destruir qualidade de entrada. | REQ-VID-TRIM-006, REQ-VID-TRIM-008 |
| Estado, progresso, cancelamento e resultado | Sim | Essencial pois a extração de vídeo pode não ser instantânea (especialmente quando ocorre *re-encoding* frame-accurate). Cancelamento coberto no UC. | REQ-VID-TRIM-007, REQ-VID-TRIM-010 |
| Falhas durante o processamento | Sim | Vídeos frequentemente apresentam frames corrompidos, implicando graceful fallback do decodificador. | REQ-VID-TRIM-007 |
| Persistência e expiração dos ficheiros | Não | Fora do âmbito. Assumido que os serviços de *storage* subjacentes da plataforma cuidam do TTL (Time-To-Live) e espaço partilhado. Impacto restrito na limpeza de ficheiros temporários em caso de falha. | N/A |
| Perfis e contagem de operações | Sim | A lógica de quotas da ferramenta de imagem do PictuRAS precisa de suportar as deduções da vertente vídeo. | REQ-VID-TRIM-006, REQ-VID-TRIM-009 |
| Encadeamento de ferramentas e processamento em lote | Não | Fora de âmbito para o MVP de recorte (a ferramenta fundacional opera atomicamente por validação). | N/A |

### 4.2 Impacto no sistema existente

| **Elemento existente afetado** | **Impacto (Manter / Estender / Alterar)** | **Descrição do impacto** | **Requisito(s) relacionado(s)** |
|--------------------------------|-------------------------------------------|--------------------------|--------------------------------|
| Mecanismo de contabilização de operações | Estender | O sistema de quotas do PictuRAS precisa reconhecer um "corte de vídeo" como uma operação descontável idêntica a uma transformação de imagem estática. | REQ-VID-TRIM-006, REQ-VID-TRIM-009 |
| Fila assíncrona de processamento e *workers* | Estender | O gestor de *jobs* e *workers* tem de introduzir bibliotecas (ex: FFmpeg) e lidar com tempos de timeout mais longos devido a recodificação de vídeo. | REQ-VID-TRIM-004, REQ-VID-TRIM-007, REQ-VID-TRIM-010 |
| Gestor de ficheiros temporários (Cache) | Alterar | Modificação do ciclo de vida: precisa lidar com volumes de I/O em GBs e ter gatilhos robustos para limpar caches no caso do processamento de extração abortar. | REQ-VID-TRIM-007, REQ-VID-TRIM-008 |
| Interface do utilizador (UI/Canvas) | Estender | A UI precisa introduzir abstrações temporais (timeline multitrack, play/pause, scrubbers) para permitir demarcação de intervalos, algo inexistente no editor de fotos. | REQ-VID-TRIM-001, REQ-VID-TRIM-002, REQ-VID-TRIM-005 |

### 4.3 Matriz de Rastreabilidade Atualizada

| **Elemento de origem** | **Descrição abreviada** | **Requisito(s) relacionado(s)** |
|------------------------|-------------------------|--------------------------------|
| Passo 1, Passo 2 | Controlos interativos e ajuste na UI | REQ-VID-TRIM-001 |
| Passo 2, Passo 3 | Pré-visualização de frames sincronizada com marcadores | REQ-VID-TRIM-002 |
| FA1, RN3, DQ-002 | Extração por *stream copy* baseada em *keyframes* e eficiência | REQ-VID-TRIM-004, REQ-VID-TRIM-011 |
| E1, RN2 | Bloqueio de submissões inconsistentes ($<0.5s$ ou invalidadas) | REQ-VID-TRIM-005 |
| E2, RN1 | Gestão de duração permitida com base nos perfis (60s/300s/3600s) | REQ-VID-TRIM-006 |
| E3, Garantia Mínima | Reposição de falhas e prevenção de débito de quotas indevido | REQ-VID-TRIM-007 |
| Garantia Sucesso, Passo 6 | Manutenção estrita da integridade audiovisual (resolução/FPS) | REQ-VID-TRIM-008 |
| Passo 6, RN4 | Contabilização e debitação de cota unitária por corte válido | REQ-VID-TRIM-009 |
| Secção 4.1.3, Passo 5/6 | Monitorização do estado/progresso de processamento em backend | REQ-VID-TRIM-010 |
| Passo 5, DQ-001 | Garantia de manutenção de alinhamento milimétrico A/V (*desync*) | REQ-VID-TRIM-003 |

**Decisões de qualidade introduzidas nesta aula**

| **ID** | **Decisão de qualidade** | **Justificação** | **Requisito(s) relacionado(s)** |
|--------|--------------------------|-----------------|--------------------------------|
| DQ-001 | Tolerância a desfasamento A/V restrita a um limite semi-percetível no MVP (<50ms). | Desfasamentos severos degradam totalmente a utilidade de vídeo. 50ms é geralmente impercetível em conteúdo amador não musical, reduzindo a complexidade de transcodificação no MVP. | REQ-VID-TRIM-003 |
| DQ-002 | Cópia direta (*stream copy*) como mecanismo primário de escalabilidade de cortes. | Uma operação de trim de um filme longo com *re-encoding* paralisa a máquina virtual; forçar *stream copy* onde possível minimiza tempos de resposta e uso global de CPU. | REQ-VID-TRIM-011 |