#import "../template.typ": *

= Efeitos colaterais noutros requisitos

#tab([Efeitos da refatoração noutros requisitos não funcionais],
  tabela(
    colunas: (3cm, 1fr),
    [Requisito], [Efeito],
    [Segurança (+)], [O gateway passa a verificar o token antes de ler o corpo; um pedido sem token deixa de obrigar a ler 1 GB. A recusa pelo `Content-Length` reduz o custo de pedidos abusivos.],
    [Segurança (−)], [O `video_autoscaler` monta `/var/run/docker.sock`, o que lhe dá controlo total sobre o Docker do anfitrião. Mitigações possíveis: um proxy do socket só com as operações necessárias, ou correr o autoscaler numa rede isolada. Não foram aplicadas.],
    [Utilização de disco], [O streaming troca RAM por disco temporário: ≈ 1 GB por carregamento de 1 GB em curso no `projects`, mais a cache de página correspondente. Não medimos o pico de disco; com M3 = 4 estimamos ≈ 4 GB em simultâneo.],
    [Fiabilidade], [Os ficheiros temporários são apagados no fim e em caso de erro. Uma réplica removida a meio devolve a mensagem à fila (testado em `test_worker_rnf02.py`). Encontrámos uma fragilidade *pré-existente*: o nginx resolve o nome `api_gateway` só no arranque; se o gateway reiniciar e mudar de IP, o nginx responde 502 até ser reiniciado. A refatoração não a corrigiu.],
    [Comportamento temporal], [O `proxy_read_timeout` de 60 s do nginx passou a ser o limite de concorrência no carregamento (M3 com 8 em paralelo). Na base o limite era a memória.],
    [Manutenibilidade], [Mais dois serviços (`video_preview_tool`, `video_autoscaler`) e uma fila nova para documentar e manter. A regra de escala é uma função pura com testes, o que facilita alterá-la.],
    [Capacidade de CPU], [As réplicas extra disputam CPU com o resto da stack, incluindo o worker de pré-visualização (Secção 4.6).],
  ),
)
