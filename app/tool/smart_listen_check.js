// Offline check for the clap-impulse detector in web/smart_listen.js.
// Run: node app/tool/smart_listen_check.js   (uses synthetic audio only)
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const sandbox = { window: {}, console };
sandbox.window = sandbox;
vm.createContext(sandbox);
vm.runInContext(
  fs.readFileSync(path.join(__dirname, '..', 'web', 'smart_listen.js'), 'utf8'),
  sandbox);
const count = sandbox.SmartListen._countImpulses;

const RATE = 48000;
let seed = 7;
const rnd = () => ((seed = (seed * 16807) % 2147483647) / 2147483647) * 2 - 1;

// Voiced "speech": 180 Hz harmonics shaped like vowels, 3 syllables/sec,
// with a short consonant burst at the start of each syllable (default
// ~10 dB under the vowel peak, like real plosives).
function speech(buf, amp, burst = 0.12) {
  for (let i = 0; i < buf.length; i++) {
    const t = i / RATE;
    const syl = Math.max(0, Math.sin(2 * Math.PI * 3 * t)) ** 0.5;
    let v = 0;
    for (let h = 1; h <= 12; h++) {
      v += Math.sin(2 * Math.PI * 180 * h * t) / h ** 1.3;
    }
    buf[i] += amp * syl * v * 0.35 + 0.002 * rnd();
  }
  // soft plosives at each syllable start
  for (let s = 0; s * RATE / 3 < buf.length; s++) {
    const at = Math.round(s * RATE / 3);
    for (let j = 0; j < 0.012 * RATE && at + j < buf.length; j++) {
      buf[at + j] += amp * burst * rnd() * Math.exp(-j / (0.004 * RATE));
    }
  }
}
function clap(buf, atSec, amp) {
  const at = Math.round(atSec * RATE);
  for (let j = 0; j < 0.05 * RATE && at + j < buf.length; j++) {
    buf[at + j] += amp * rnd() * Math.exp(-j / (0.008 * RATE));
  }
}

const sec = 1.5;
const mk = () => new Float32Array(Math.round(sec * RATE));
const cases = [];
const run = (name, build, ok) => {
  const b = mk();
  build(b);
  const n = count(b, RATE);
  cases.push({ name, n, pass: ok(n) });
};

run('silence', () => {}, (n) => n === 0);
run('talking only (normal)', (b) => speech(b, 0.3), (n) => n === 0);
run('talking only (loud)', (b) => speech(b, 0.8), (n) => n === 0);
// Known limit: a consonant nearly as loud as the vowels looks like a clap.
// Printed for information; does not fail the run.
{
  const b = mk(); speech(b, 0.3, 0.25);
  console.log(`INFO  very harsh consonants (~60% of vowel peak): impulses=${count(b, RATE)}`);
}
run('claps only, 2 hits', (b) => { clap(b, 0.3, 0.5); clap(b, 0.8, 0.5); },
  (n) => n === 2);
run('claps + loud voice, 3 hits',
  (b) => { speech(b, 0.6); clap(b, 0.3, 0.5); clap(b, 0.7, 0.5); clap(b, 1.1, 0.5); },
  (n) => n >= 2);
run('soft claps + voice, 2 hits',
  (b) => { speech(b, 0.5); clap(b, 0.4, 0.3); clap(b, 1.0, 0.3); },
  (n) => n >= 2);
run('claps closer than 100 ms count once',
  (b) => { clap(b, 0.5, 0.5); clap(b, 0.55, 0.5); }, (n) => n === 1);
run('sustained noise (hiss/fan)', (b) => {
  for (let i = 0; i < b.length; i++) b[i] = 0.05 * rnd();
}, (n) => n === 0);
run('piano-ish decaying tone', (b) => {
  for (let k = 0; k < 3; k++) {
    const at = Math.round((0.1 + k * 0.45) * RATE);
    for (let j = 0; at + j < b.length; j++) {
      b[at + j] += 0.4 * Math.sin(2 * Math.PI * 262 * (j / RATE)) *
        Math.exp(-j / (0.4 * RATE));
    }
  }
}, (n) => n === 0);

let failed = 0;
for (const c of cases) {
  console.log(`${c.pass ? 'PASS' : 'FAIL'}  ${c.name}  (impulses=${c.n})`);
  if (!c.pass) failed++;
}
process.exit(failed ? 1 : 0);
