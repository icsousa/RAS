#import "../template.typ": *

= Ambiente e método de medição

== Ambiente

A base e a final foram medidas no mesmo portátil, com a mesma configuração e no mesmo dia (18 de novembro de 2026), sem outras aplicações pesadas abertas.

#tab([Ambiente de medição],
  tabela-campos(
    [Portátil], [ASUS VivoBook X515JA],
    [CPU], [Intel Core i7-1065G7 (4 núcleos, 8 threads)],
    [RAM], [12 GB (11 GiB utilizáveis), *sem swap*],
    [Sistema operativo], [Manjaro Linux, kernel 7.2.9],
    [Docker], [Docker Engine 29.8.2 nativo (não Docker Desktop), cgroup v2, Docker Compose 5.6.0; o Docker vê os 8 CPUs e toda a RAM],
    [Registo completo], [`medicoes/resultados/base/ambiente.txt`],
  ),
)

== Instrumentos

- `medicoes/medir.py` (biblioteca padrão do Python, mais `docker`, `curl` e `ffmpeg`) gera os vídeos de teste e corre os ensaios contra a stack real em Docker. Os resultados ficam em JSON/CSV em `medicoes/resultados/base/` e `medicoes/resultados/final/`.
- A memória (M1) é lida do cgroup de cada contentor: `memory.peak` menos `memory.current` em repouso, depois de reiniciar o serviço. Foi sempre esta a fonte; o recurso ao `docker stats` nunca foi usado.
- A M3 usa o override `medicoes/docker-compose.medicoes.yaml`, que limita a 2 GB o `api_gateway`, o `projects` e o `img_storage`.
- A elasticidade lê a API de gestão do RabbitMQ a cada segundo e os logs dos workers (`[video] msg=…`).
- A M5 é manual, no browser.

As instruções para repetir as medições estão em `medicoes/README.md` e no Anexo A.
