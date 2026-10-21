var createError = require("http-errors");
var express = require("express");
var path = require("path");
var cookieParser = require("cookie-parser");
var logger = require("morgan");
const mongoose = require("mongoose");

const { router: projectsRouter, process_msg } = require("./routes/projects");
const { videosRouter } = require("./routes/videos");
const videoService = require("./services/video");
const { consumeResults } = require("./utils/videoQueue");

// Run Docker
const mongoDB = "mongodb://projects_mongoDB:27018/project";

mongoose.connect(mongoDB, { useNewUrlParser: true, useUnifiedTopology: true });

const db = mongoose.connection;

db.on("error", console.error.bind(console, "Error connecting to Mongodb"));
db.once("open", () => {
  console.log("Mongodb connection successful");
});

var app = express();

// view engine setup
app.set("views", path.join(__dirname, "views"));
app.set("view engine", "jade");

app.use(logger("dev"));
app.use(express.json({ limit: "2mb" }));
app.use(express.urlencoded({ extended: false }));
app.use(cookieParser());
app.use(express.static(path.join(__dirname, "public")));

// Vídeo (Fase 1): montado antes do router de projetos para as rotas /:user/:project/videos...
app.use("/", videosRouter(videoService));
app.use("/", projectsRouter);

// Start the message processing
process_msg();
consumeResults((msg) => videoService.handleResult(msg));

// catch 404 and forward to error handler
app.use(function (req, res, next) {
  next(createError(404));
});

// error handler
app.use(function (err, req, res, next) {
  // set locals, only providing error in development
  res.locals.message = err.message;
  res.locals.error = req.app.get("env") === "development" ? err : {};

  // render the error page
  res.status(err.status || 500).jsonp(err);
});

module.exports = app;
