// Mensagens de vídeo no RabbitMQ (DA-03).
//  - publica pedidos em `video_queue` (consumida pelo worker Tools/video);
//  - consome `video_results_queue` (progresso, sucesso, falha) com ack só depois de tratada;
//  - publica eventos para o browser em `ws_queue` (WS Gateway).
// Ao contrário de utils/rabbit_mq.js, mantém um canal aberto em vez de uma ligação por mensagem.
const amqp = require("amqplib/callback_api");

const EXCHANGE = "picturas";
const REQUEST_QUEUE = process.env.VIDEO_REQUEST_QUEUE || "video_queue";
const RESULTS_QUEUE = process.env.VIDEO_RESULTS_QUEUE || "video_results_queue";
const WS_QUEUE = "ws_queue";

const url = `amqp://${process.env.RABBITMQ_USER}:${process.env.RABBITMQ_PASS}@${process.env.RABBITMQ_HOST}:${process.env.RABBITMQ_PORT}`;

let channel = null;
let connecting = null;
let resultHandler = null; // para voltar a consumir depois de uma quebra de ligação

function connect() {
  if (channel) return Promise.resolve(channel);
  if (connecting) return connecting;
  connecting = new Promise((resolve, reject) => {
    amqp.connect(url, (err, conn) => {
      if (err) {
        connecting = null;
        return reject(err);
      }
      conn.on("close", () => {
        channel = null;
        connecting = null;
        if (resultHandler) setTimeout(() => consumeResults(resultHandler), 5000);
      });
      conn.on("error", () => {});
      conn.createChannel((err2, ch) => {
        if (err2) {
          connecting = null;
          return reject(err2);
        }
        ch.assertExchange(EXCHANGE, "direct", { durable: true });
        for (const q of [REQUEST_QUEUE, RESULTS_QUEUE, WS_QUEUE]) {
          ch.assertQueue(q, { durable: true });
          ch.bindQueue(q, EXCHANGE, q);
        }
        channel = ch;
        connecting = null;
        resolve(ch);
      });
    });
  });
  return connecting;
}

async function publish(queue, msg) {
  const ch = await connect();
  ch.publish(EXCHANGE, queue, Buffer.from(JSON.stringify(msg)), { persistent: true });
}

const publishRequest = (msg) => publish(REQUEST_QUEUE, msg);
const publishWs = (msg) => publish(WS_QUEUE, msg);

// Consome os resultados do worker; tenta voltar a ligar se a ligação cair.
function consumeResults(handler) {
  resultHandler = handler;
  const start = () =>
    connect()
      .then((ch) => {
        ch.prefetch(4);
        ch.consume(RESULTS_QUEUE, async (msg) => {
          if (!msg) return;
          try {
            await handler(JSON.parse(msg.content.toString()));
          } catch (e) {
            console.error("[video] erro ao tratar resultado:", e);
          }
          ch.ack(msg);
        });
        console.log(`[video] a consumir ${RESULTS_QUEUE}`);
      })
      .catch((e) => {
        console.error("[video] RabbitMQ indisponível, nova tentativa em 5 s:", e.message);
        setTimeout(start, 5000);
      });
  start();
}

module.exports = { publishRequest, publishWs, consumeResults, REQUEST_QUEUE, RESULTS_QUEUE };
