#import "../template.typ": *

#set heading(numbering: "A.1.")
#counter(heading).update(0)

= Instruções de execução

*Pré-requisitos.* Docker Engine 24+ com Docker Compose v2, 8 GB de RAM livres (16 GB recomendados) e cerca de 15 GB de disco, como na _baseline_.

*Lançar a solução.*

```bash
unzip solucao-ext-mvp.zip && cd picturas-27
docker compose up --build        # primeira vez: 15–30 min
```

Abrir #link("https://localhost:8080")[`https://localhost:8080`], aceitar o certificado autoassinado, criar uma conta (ou usar o modo anónimo), criar um projeto e carregar no botão *Vídeos*. Para testar os perfis, as contas Registado e Premium criam-se no registo e na página de subscrição (pagamento simulado).

*Vídeo de exemplo* (MP4 H.264/AAC, 30 s, 1080p), gerado com FFmpeg:

```bash
ffmpeg -f lavfi -i testsrc2=s=1920x1080:r=30:d=30 -f lavfi -i sine=f=440:d=30 \
       -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest exemplo.mp4
```

*Testes automáticos.*

```bash
cd Tools/video && python -m unittest discover -s tests -v    # requer ffmpeg, Pillow e numpy
RUN_PERF=1 python -m unittest discover -s tests -v           # inclui os testes de desempenho
cd ../../projects && node --test test/*.test.js               # sem dependências
```

*Diagnóstico.* `docker compose logs -f video_tool projects`; filas e mensagens em #link("http://localhost:15672")[`http://localhost:15672`] (`user` / `password`).

= Glossário

#tabela(
  colunas: (4cm, 1fr),
  [Termo], [Definição],
  [Trabalho de processamento], [Execução assíncrona de uma ferramenta de vídeo sobre um vídeo de origem, com estado (Em fila, A processar, Concluído, Falhado, Cancelado), progresso e, se concluída, um vídeo resultado.],
  [Versão (de vídeo)], [Vídeo produzido por uma operação concluída, derivado de outro vídeo do projeto, que se mantém inalterado (RNG-05).],
  [Operação (quota)], [Unidade do limite diário do perfil Registado (5 por dia na _baseline_, consumidas pelas ferramentas de IA de imagem); um trabalho de vídeo concluído conta como uma operação (RNG-01).],
  [Fotograma (_frame_)], [Cada uma das imagens que compõem um vídeo.],
  [Keyframe (codificação)], [Fotograma codificado de forma independente (_I-frame_), a partir do qual um vídeo H.264 pode ser descodificado; usado no corte rápido (UC-VID-001).],
  [Keyframe (animação)], [Ponto da _timeline_ em que o utilizador fixa a posição e dimensão da moldura de enquadramento (UC-VID-002).],
  [Contentor / _codec_], [O contentor (MP4, MOV) agrupa os fluxos de vídeo, áudio e legendas; o _codec_ (H.264, AAC) define como cada fluxo é comprimido.],
  [Recodificação (_re-encoding_)], [Descodificar e voltar a codificar um fluxo, necessário quando os fotogramas ou as amostras mudam.],
  [Cópia direta (_stream copy_)], [Copiar um fluxo para o ficheiro de saída sem o recodificar; rápido e sem perdas.],
  [PTS], [_Presentation Time Stamp_: instante em que cada fotograma deve ser apresentado; alterado para mudar a velocidade.],
  [Correção de tom (_pitch correction_)], [Ajuste do áudio acelerado ou abrandado para manter a altura original da voz ou do som.],
  [Fluxo ótico (_optical flow_)], [Técnica que estima o movimento entre fotogramas para gerar fotogramas intermédios; não usada no MVP (DQ-009).],
  [Hardcode], [Texto desenhado diretamente nos fotogramas do vídeo; não pode ser desligado pelo leitor.],
  [Soft-sub], [Legendas guardadas numa faixa separada do contentor, que o leitor pode mostrar ou ocultar.],
  [SRT / VTT], [Formatos de ficheiro de legendas com blocos de texto e respetivos instantes de início e fim.],
  [Tofu], [Retângulo vazio mostrado no lugar de um carácter que a fonte não consegue desenhar.],
  [LUT 3D (`.cube`)], [Tabela de correspondência que transforma cada cor de entrada numa cor de saída, usada em gradação de cor.],
  [Rácio de aspeto], [Proporção entre largura e altura de uma imagem ou moldura (e.g., 16:9, 9:16, 1:1).],
  [Pré-visualização], [Simulação do resultado no cliente, sem criar um trabalho de processamento (DQ-002).],
)
