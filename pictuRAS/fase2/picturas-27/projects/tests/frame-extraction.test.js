const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { validateFrameExtraction, insertPipelineTool, imageTools, videoPipeline, videoOps } = require('../utils/video');
const { frameFiles, persistFrameResults } = require('../utils/frameResults');

const extraction = (params = {}) => ({ procedure: 'extract_frames', params: { mode: 'count', count: 6, interval: 2, format: 'png', ...params } });

test('extraction is project-wide and terminal, with ordinary effects inserted before it', () => {
  const first = insertPipelineTool([], extraction());
  const tools = insertPipelineTool(first, { procedure: 'brightness', params: { brightness: 0.3 } });
  assert.deepEqual(tools.map(t => [t.procedure, t.position]), [['brightness', 0], ['extract_frames', 1]]);
  assert.equal(validateFrameExtraction(tools), null);
  const project = { tools, imgs: [{ _id: 'v1', media_type: 'video' }, { _id: 'v2', media_type: 'video' }, { _id: 'i', media_type: 'image' }] };
  assert.deepEqual(imageTools(project).map(t => t.procedure), ['brightness']);
  assert.deepEqual(videoPipeline(project, 'v1'), videoPipeline(project, 'v2'));
  assert.equal(videoOps(project), 4);
  assert.match(validateFrameExtraction(insertPipelineTool(tools, extraction())), /Only one/);
  assert.match(validateFrameExtraction([...tools].reverse().map((t, position) => ({ ...t, position }))), /last tool/);
});

test('extraction validates active mode parameters and disallows targeted/potentially unbounded inputs', () => {
  for (const count of [0, -1, 101, 1.5, '6', null, true, Infinity, NaN]) {
    assert.match(validateFrameExtraction([extraction({ count })]), /integer between 1 and 100/);
  }
  for (const interval of [0, -1, '2', null, true, Infinity, NaN]) {
    assert.match(validateFrameExtraction([extraction({ mode: 'interval', interval })]), /positive number/);
  }
  assert.equal(validateFrameExtraction([extraction({ count: 1, format: 'jpeg' })]), null);
  assert.equal(validateFrameExtraction([extraction({ count: 100 })]), null);
  assert.equal(validateFrameExtraction([extraction({ mode: 'interval', interval: 0.01 })]), null);
  assert.match(validateFrameExtraction([extraction({ mode: 'random' })]), /mode/);
  assert.match(validateFrameExtraction([extraction({ format: 'svg' })]), /format/);
  assert.match(validateFrameExtraction([extraction({ imgId: 'one-video' })]), /all videos/);
});

function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'frame-result-test-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const dir = path.join(root, 'out', 'job-frames-uuid');
  fs.mkdirSync(dir, { recursive: true });
  const frames = [0, 2].map((time, i) => {
    const file = path.join(dir, `frame-${i}-${time * 1000}ms.png`);
    fs.writeFileSync(file, 'test file');
    return { file, time };
  });
  const process = { img_id: 'video-a', project_id: 'project', user_id: 'user', token: 7, new_img_uri: path.join(root, 'out', 'video.mp4') };
  return { root, dir, output: { type: 'frames', imageURI: dir, frames }, process };
}

test('manifest validation rejects escaped, duplicate and oversized frame output before upload', (t) => {
  const { root, output, process } = fixture(t);
  assert.equal(frameFiles(output, process).length, 2);
  assert.match(frameFiles(output, process)[0].name, /^video-a-frame-/);
  assert.throws(() => frameFiles({ ...output, frames: [] }, process), /between 1 and 100/);
  assert.throws(() => frameFiles({ ...output, frames: Array(101).fill(output.frames[0]) }, process), /between 1 and 100/);
  assert.throws(() => frameFiles({ ...output, frames: [output.frames[0], output.frames[0]] }, process), /path/);
  const outside = path.join(root, 'outside.png');
  fs.writeFileSync(outside, 'outside');
  assert.throws(() => frameFiles({ ...output, frames: [{ file: outside, time: 0 }] }, process), /path/);
  const link = path.join(output.imageURI, 'linked.png');
  fs.symlinkSync(outside, link);
  assert.throws(() => frameFiles({ ...output, frames: [{ file: link, time: 0 }] }, process), /path/);
  assert.throws(() => frameFiles({ ...output, frames: [{ ...output.frames[0], time: -1 }] }, process), /Invalid extracted frame/);
});

test('all extracted images retain the source ID and run token; upload failure rolls back only this batch', async (t) => {
  const { output, process } = fixture(t);
  const records = [], removedRecords = [], removedImages = [];
  const storage = {
    upload: async (_, name) => `stored-${name}`,
    create: async result => { records.push(result); return { _id: records.length }; },
    removeResult: async id => removedRecords.push(id),
    removeImage: async key => removedImages.push(key),
  };
  await persistFrameResults(output, process, storage);
  assert.equal(records.length, 2);
  assert.ok(records.every(r => r.type === 'image' && r.token === 7 && r.img_id === 'video-a'));
  assert.notEqual(records[0].file_name, records[1].file_name);
  assert.deepEqual(removedImages, []);
  records.length = 0;
  storage.create = async result => {
    records.push(result);
    if (records.length === 2) throw new Error('database failure');
    return { _id: 'first-new-result' };
  };
  await assert.rejects(persistFrameResults(output, process, storage), /database failure/);
  assert.deepEqual(removedRecords, ['first-new-result']);
  assert.equal(removedImages.length, 2);
});
