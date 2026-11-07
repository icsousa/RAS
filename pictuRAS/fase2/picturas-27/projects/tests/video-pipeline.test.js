const test = require('node:test');
const assert = require('node:assert/strict');
const { imageTools, videoPipeline, videoOps, unsupportedVideoTools } = require('../utils/video');

test('captions apply to all videos, while images skip them and trim stays targeted', () => {
  const project = {
    imgs: [{ _id: 'a', media_type: 'video' }, { _id: 'b', media_type: 'video' }, { _id: 'c', media_type: 'image' }],
    tools: [
      { position: 2, procedure: 'subtitles', params: {} },
      { position: 0, procedure: 'brightness', params: { brightness: 0.5 } },
      { position: 1, procedure: 'trim', params: { imgId: 'a', start: 0, end: 2 } },
    ],
  };
  assert.deepEqual(imageTools(project).map(t => t.procedure), ['brightness']);
  assert.deepEqual(videoPipeline(project, 'a').map(t => t.procedure), ['brightness', 'trim', 'subtitles']);
  assert.deepEqual(videoPipeline(project, 'b').map(t => t.procedure), ['brightness', 'subtitles']);
  assert.equal(videoOps(project), 5);
  assert.deepEqual(unsupportedVideoTools(project), []);
  project.tools = [project.tools[0]];
  assert.deepEqual(imageTools(project), []);
  assert.equal(videoOps(project), 2);
});
