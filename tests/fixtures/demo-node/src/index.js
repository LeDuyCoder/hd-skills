import { greet } from './greeting.js';

export function run(name = 'world') {
  return greet(name);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  console.log(run());
}
