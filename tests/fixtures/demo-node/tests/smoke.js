import assert from 'node:assert/strict';
import { run } from '../src/index.js';

assert.equal(run(), 'Hello, world!');
assert.equal(run('Codex'), 'Hello, Codex!');
