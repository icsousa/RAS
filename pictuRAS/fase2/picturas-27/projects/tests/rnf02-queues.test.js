// Regression tests for the RNF-02 refactoring (elasticity of video processing):
// video previews go to their own queue, everything else keeps its queue.
// Run inside the container: docker compose exec projects node --test
//
// Written with AI assistance (Claude) and reviewed by the group (PL3-G7).
const test = require("node:test");
const assert = require("node:assert/strict");
const { queueFor } = require("../utils/project_msg");

test("a video preview goes to video_preview_queue", () => {
  assert.equal(queueFor("video", { preview: true, tools: [] }), "video_preview_queue");
});

test("a full video job stays on video_queue", () => {
  assert.equal(queueFor("video", { preview: false, tools: [] }), "video_queue");
  assert.equal(queueFor("video", {}), "video_queue");
});

test("image tools keep their queues, previews included", () => {
  assert.equal(queueFor("brightness", { preview: true }), "brightness_queue");
  assert.equal(queueFor("cut_ai", {}), "cut_ai_queue");
});
