export function greet(name) {
  const normalizedName = String(name).trim();
  return `Hello, ${normalizedName || 'world'}!`;
}
