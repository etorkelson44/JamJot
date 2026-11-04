import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

const js=readFileSync(new URL('../web/coin_drop.js',import.meta.url),'utf8');
const wav=readFileSync(new URL('../assets/audio/coin_drop.wav',import.meta.url));
assert.equal(wav.toString('ascii',0,4),'RIFF');
assert.equal(wav.toString('ascii',8,12),'WAVE');
assert.equal(wav.readUInt16LE(22),1);
assert.equal(wav.readUInt32LE(24),44100);
assert.equal(wav.readUInt16LE(34),16);
const duration=wav.readUInt32LE(40)/88200;
assert.ok(duration>1.8 && duration<2.1);
let peak=0;
for(let i=44;i<wav.length;i+=2)peak=Math.max(peak,Math.abs(wav.readInt16LE(i)));
assert.ok(peak>10000 && peak<30000);
console.log('PASS bundled WAV: playable PCM, brief duration, no clipped samples');

async function setup({suspended=false, failure=false}={}) {
  const events={};let starts=0,stops=0,fetches=0;
  const node=()=>({connect(){return this;},disconnect(){}});
  class Context {
    state=suspended?'suspended':'running';destination={};
    async resume() { if(!suspended)this.state='running'; }
    async decodeAudioData() { return {duration}; }
    createGain() {return {...node(),gain:{value:0}};}
    createBufferSource() {return {...node(),start(){starts++;},stop(){stops++;}};}
  }
  const window={AudioContext:Context,addEventListener(name,listener){events[name]=listener;}};
  vm.runInNewContext(js,{window,document:{baseURI:'http://localhost:8787/market-preview/'},URL,Date,
    fetch:async url=>{fetches++;assert.equal(String(url),'http://localhost:8787/market-preview/assets/assets/audio/coin_drop.wav');return {ok:!failure,arrayBuffer:async()=>new ArrayBuffer(1)};}});
  return {window,events,counts:()=>({starts,stops,fetches})};
}
const run=await setup();
assert.equal(run.counts().starts,0);
await run.events.pointerdown();
assert.equal(run.counts().starts,0);
assert.equal(await run.window.jjCoinDrop(),true);
assert.equal(await run.window.jjCoinDrop(),true);
assert.deepEqual(run.counts(),{starts:2,stops:1,fetches:1});
console.log('PASS sound only on reward request, cached local audio, overlapping sound stopped');
const blocked=await setup({suspended:true});
assert.equal(await blocked.window.jjCoinDrop(),false);
assert.equal(blocked.counts().starts,0);
console.log('PASS browser audio restriction fails quietly without a delayed jingle');
const missing=await setup({failure:true});
assert.equal(await missing.window.jjCoinDrop(),false);
assert.equal(missing.counts().starts,0);
console.log('PASS missing audio never blocks the visual reward');
