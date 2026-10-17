import { greet } from './greeting.js';
import { pathToFileURL } from 'node:url';

export function run(name = 'world') {
  return greet(name);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  console.log(run());
}
