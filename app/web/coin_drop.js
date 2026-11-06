// Coin sound: Pixabay "Retro coin 4" by Driken5482 (assets/audio/coin_retro.mp3).
// One blip per coin as it drops into the jar, stepping up a pentatonic scale.
// Only runs when the app asks for it (a reward), never on page load.
(function () {
  var SCALE = [0, 2, 4, 7, 9, 12, 14, 16, 19, 21];
  var ctx = null, buf = null, loading = null, live = [];
  function ac() {
    if (ctx) return ctx;
    var C = window.AudioContext || window.webkitAudioContext;
    if (!C) return null;
    ctx = new C();
    return ctx;
  }
  function load(c) {
    if (buf) return Promise.resolve(buf);
    if (!loading) {
      var url = new URL('assets/assets/audio/coin_retro.mp3', document.baseURI).toString();
      loading = fetch(url)
        .then(function (r) { if (!r.ok) throw new Error('missing'); return r.arrayBuffer(); })
        .then(function (b) { return c.decodeAudioData(b); })
        .then(function (b) { buf = b; return b; })
        .catch(function () { loading = null; return null; });
    }
    return loading;
  }
  // Browsers only allow audio after a tap: warm up quietly on the first one.
  window.addEventListener('pointerdown', function () {
    var c = ac();
    if (c) { if (c.state === 'suspended' && c.resume) c.resume().catch(function () {}); load(c); }
  });
  // csv = milliseconds from now for each coin, e.g. "0,105,210".
  window.jjCoinPings = function (csv) {
    var c = ac();
    if (!c) return Promise.resolve(false);
    var t0 = Date.now();
    var delays = String(csv).split(',').map(Number).filter(function (n) { return n >= 0; }).slice(0, 24);
    live.forEach(function (s) { try { s.stop(); } catch (e) {} });
    live = [];
    var ready = c.state === 'suspended' && c.resume ? c.resume().catch(function () {}) : Promise.resolve();
    return ready.then(function () { return load(c); }).then(function (b) {
      if (!b || c.state !== 'running') return false;
      var gone = Date.now() - t0;
      delays.forEach(function (d, i) {
        var s = c.createBufferSource();
        s.buffer = b;
        s.playbackRate.value = Math.pow(2, SCALE[Math.min(i, SCALE.length - 1)] / 12);
        var g = c.createGain();
        g.gain.value = 0.55;
        s.connect(g).connect(c.destination);
        s.start(c.currentTime + Math.max(0, d - gone) / 1000);
        live.push(s);
      });
      return true;
    }).catch(function () { return false; });
  };
})();
