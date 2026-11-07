const test = require('node:test');
const assert = require('node:assert/strict');
const { dispatchProcessBatch } = require('../utils/processBatch');

// Simulate workers completing immediately when published, which used to permit
// the first source to commit before the second source had even been registered.
test('a fast first worker cannot commit while later sources are still being scheduled', async () => {
  const pending = new Set();
  const completionCounts = [];
  const jobs = ['video-a', 'video-b', 'image-c'].map(id => ({ process: { _id: id } }));
  await dispatchProcessBatch(jobs, {
    create: async process => { pending.add(process._id); return process; },
    remove: async process => pending.delete(process._id),
    send: async job => {
      pending.delete(job.process._id);
      completionCounts.push(pending.size);
    },
  });
  assert.deepEqual(completionCounts, [2, 1, 0]);
});

test('registration failure starts no workers and rolls back only newly registered jobs', async () => {
  const pending = new Set(['previous-run']);
  const published = [];
  const jobs = ['first', 'failing', 'last'].map(id => ({ process: { _id: id } }));
  await assert.rejects(dispatchProcessBatch(jobs, {
    create: async process => {
      if (process._id === 'failing') throw new Error('database unavailable');
      pending.add(process._id);
      return process;
    },
    remove: async process => pending.delete(process._id),
    send: async job => published.push(job),
  }), /database unavailable/);
  assert.deepEqual(published, []);
  assert.deepEqual([...pending], ['previous-run']);
});

test('a cancelled run cannot overwrite the committed results with a delayed commit', async () => {
  const modelPath = require.resolve('../models/project');
  const controllerPath = require.resolve('../controllers/project');
  const originalModel = require.cache[modelPath];
  const originalController = require.cache[controllerPath];
  const state = { user_id: 'owner', _id: 'project', activeToken: 8, committedToken: 6 };
  require.cache[modelPath] = { id: modelPath, filename: modelPath, loaded: true, exports: {
    findOneAndUpdate(filter, update) {
      return { exec: async () => {
        if (Object.entries(filter).some(([key, value]) => state[key] !== value)) return null;
        Object.assign(state, update.$set);
        return { ...state };
      }};
    },
  }};
  delete require.cache[controllerPath];
  try {
    const Project = require('../controllers/project');
    assert.equal(await Project.commitRunIfActive('owner', 'project', 7, []), null);
    assert.equal(state.committedToken, 6);
    const result = await Project.commitRunIfActive('owner', 'project', 8, [{ procedure: 'extract_frames' }]);
    assert.equal(result.committedToken, 8);
    assert.equal(result.resultsToken, 8);
  } finally {
    if (originalModel) require.cache[modelPath] = originalModel; else delete require.cache[modelPath];
    if (originalController) require.cache[controllerPath] = originalController; else delete require.cache[controllerPath];
  }
});
