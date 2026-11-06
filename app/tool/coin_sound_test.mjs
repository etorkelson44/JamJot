import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

const js=readFileSync(new URL('../web/coin_drop.js',import.meta.url),'utf8');
const mp3=readFileSync(new URL('../assets/audio/coin_retro.mp3',import.meta.url));
assert.ok(mp3.length>2000 && mp3.length<60000);
assert.ok(mp3[0]===0xFF || mp3.toString('ascii',0,3)==='ID3');
console.log('PASS bundled coin sound is a small mp3');

function setup({suspended=false, failure=false}={}) {
  const events={};let starts=[],fetches=0;
  const node=()=>({connect(){return this;}});
  class Context {
    state=suspended?'suspended':'running';destination={};currentTime=0;
    async resume(){ if(!suspended)this.state='running'; }
    async decodeAudioData(){ return {duration:.18}; }
    createGain(){return {...node(),gain:{value:0}};}
    createBufferSource(){const s={...node(),playbackRate:{value:1},start(){starts.push(s.playbackRate.value);},stop(){}};return s;}
  }
  const window={AudioContext:Context,addEventListener(n,l){events[n]=l;}};
  vm.runInNewContext(js,{window,document:{baseURI:'http://localhost:8787/app/'},URL,Date,Promise,Math,Number,String,
    fetch:async url=>{fetches++;assert.equal(String(url),'http://localhost:8787/app/assets/assets/audio/coin_retro.mp3');return {ok:!failure,arrayBuffer:async()=>new ArrayBuffer(1)};}});
  return {window,events,starts,fetches:()=>fetches};
}
const run=setup();
assert.equal(run.starts.length,0);
assert.equal(await run.window.jjCoinPings('0,100,200,300'),true);
assert.equal(run.starts.length,4);
assert.ok(run.starts[1]>run.starts[0] && run.starts[3]>run.starts[2]);
assert.equal(run.fetches(),1);
await run.window.jjCoinPings('0');
assert.equal(run.fetches(),1);
console.log('PASS one blip per coin, rising pitch, audio fetched once');
const blocked=setup({suspended:true});
assert.equal(await blocked.window.jjCoinPings('0,100'),false);
assert.equal(blocked.starts.length,0);
console.log('PASS browser audio restriction fails quietly');
const missing=setup({failure:true});
assert.equal(await missing.window.jjCoinPings('0'),false);
assert.equal(missing.starts.length,0);
console.log('PASS missing audio never blocks the visual reward');
