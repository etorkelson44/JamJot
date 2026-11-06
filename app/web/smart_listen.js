// JamJot "smart ears" (beta) — on-device sound classification.
//
// Everything runs in the kid's own browser: the microphone audio never
// leaves the device. We classify ~1-second windows with Google's YAMNet
// model (Apache-2.0, bundled under smart/yamnet/) via TensorFlow.js
// (bundled as smart/tf.min.js), and expose simple scores — speech, music,
// the student's instrument family, clapping — that the Flutter app polls.
//
// Nothing here loads until start() is called, so the ~17 MB of model
// files cost nothing unless a practice recording begins with smart ears
// turned on. The browser caches them after the first load.
window.SmartListen = (() => {
  let model = null;
  let classNames = null; // 521 YAMNet display names, by index
  let groups = null; // {speech:[idx], music:[idx], instrument:[idx], clap:[idx]}
  let ctx = null, stream = null, srcNode = null, procNode = null, muteNode = null;
  let timer = null;
  let ring = null, ringLen = 0, ringPos = 0, ringFilled = 0;
  let state = 'off'; // off | loading | on | error
  let errMsg = '';
  let latest = { speech: 0, music: 0, instrument: 0, clap: 0, at: 0 };
  let busy = false;

  // Which YAMNet classes count as "their instrument", per instrument name.
  // 'Musical instrument' rides along in every group as a family fallback,
  // so a slightly-misheard real instrument still scores as an instrument.
  const HINTS = {
    piano: ['Piano', 'Electric piano', 'Keyboard (musical)', 'Harpsichord'],
    guitar: ['Guitar', 'Acoustic guitar', 'Electric guitar', 'Strum',
      'Plucked string instrument'],
    ukulele: ['Ukulele', 'Plucked string instrument'],
    violin: ['Violin, fiddle', 'Bowed string instrument'],
    viola: ['Violin, fiddle', 'Bowed string instrument'],
    cello: ['Cello', 'Bowed string instrument'],
    bass: ['Bass guitar', 'Double bass'],
    drums: ['Drum', 'Drum kit', 'Snare drum', 'Bass drum', 'Percussion',
      'Cymbal', 'Hi-hat'],
    voice: ['Singing', 'Child singing', 'Choir'],
    singing: ['Singing', 'Child singing', 'Choir'],
    flute: ['Flute', 'Wind instrument, woodwind instrument'],
    clarinet: ['Clarinet', 'Wind instrument, woodwind instrument'],
    saxophone: ['Saxophone', 'Wind instrument, woodwind instrument'],
    recorder: ['Flute', 'Wind instrument, woodwind instrument'],
    trumpet: ['Trumpet', 'Brass instrument'],
    trombone: ['Trombone', 'Brass instrument'],
    'french horn': ['French horn', 'Brass instrument'],
    organ: ['Organ', 'Electronic organ', 'Hammond organ'],
    harp: ['Harp'],
    accordion: ['Accordion'],
    harmonica: ['Harmonica'],
    banjo: ['Banjo'],
    mandolin: ['Mandolin'],
    xylophone: ['Glockenspiel', 'Marimba, xylophone', 'Mallet percussion'],
    bells: ['Glockenspiel', 'Mallet percussion'],
  };
  const SPEECH = ['Speech', 'Child speech, kid speaking', 'Conversation',
    'Narration, monologue'];
  const MUSIC = ['Music'];
  const CLAP = ['Clapping', 'Applause', 'Finger snapping'];

  function loadScript(src) {
    return new Promise((resolve, reject) => {
      const s = document.createElement('script');
      s.src = src; // relative: resolves against <base href>, so GH Pages works
      s.onload = resolve;
      s.onerror = () => reject(new Error('could not load ' + src));
      document.head.appendChild(s);
    });
  }

  function parseClassMap(text) {
    // index,mid,display_name — display_name may be quoted and hold commas.
    const names = [];
    for (const line of text.split('\n').slice(1)) {
      const m = line.match(/^(\d+),[^,]+,(?:"([^"]*)"|(.*))$/);
      if (m) names[+m[1]] = (m[2] !== undefined ? m[2] : m[3]).trim();
    }
    return names;
  }

  function indicesFor(wanted) {
    const set = new Set(wanted.map((n) => n.toLowerCase()));
    const out = [];
    classNames.forEach((name, i) => {
      if (name && set.has(name.toLowerCase())) out.push(i);
    });
    return out;
  }

  function buildGroups(instrument) {
    const hints = HINTS[(instrument || '').toLowerCase()] || [];
    groups = {
      speech: indicesFor(SPEECH),
      music: indicesFor(MUSIC),
      instrument: indicesFor([...hints, 'Musical instrument']),
      clap: indicesFor(CLAP),
    };
  }

  async function ensureModel() {
    if (!window.tf) await loadScript('smart/tf.min.js');
    if (!classNames) {
      const r = await fetch('smart/yamnet_class_map.csv');
      if (!r.ok) throw new Error('class map ' + r.status);
      classNames = parseClassMap(await r.text());
    }
    if (!model) {
      model = await window.tf.loadGraphModel('smart/yamnet/model.json');
    }
  }

  function pushSamples(input) {
    for (let i = 0; i < input.length; i++) {
      ring[ringPos] = input[i];
      ringPos = (ringPos + 1) % ringLen;
    }
    ringFilled = Math.min(ringLen, ringFilled + input.length);
  }

  // Last `seconds` of audio, linearly resampled from the mic rate to 16 kHz.
  function lastWindow16k(seconds) {
    const n = Math.min(ringFilled, Math.round(seconds * ctx.sampleRate));
    const startAt = (ringPos - n + ringLen) % ringLen;
    const raw = new Float32Array(n);
    for (let i = 0; i < n; i++) raw[i] = ring[(startAt + i) % ringLen];
    const outLen = Math.round(n * 16000 / ctx.sampleRate);
    const out = new Float32Array(outLen);
    for (let i = 0; i < outLen; i++) {
      const t = i * (n - 1) / Math.max(1, outLen - 1);
      const a = Math.floor(t), b = Math.min(n - 1, a + 1);
      out[i] = raw[a] + (raw[b] - raw[a]) * (t - a);
    }
    return out;
  }

  async function classifyOnce() {
    if (busy || !model || !ctx) return;
    if (ringFilled < ctx.sampleRate * 0.975) return; // not a full second yet
    busy = true;
    try {
      const wave = lastWindow16k(0.975);
      const tf = window.tf;
      const scores = tf.tidy(() => {
        const outs = model.predict(tf.tensor1d(wave));
        const s = Array.isArray(outs) ? outs[0] : outs; // [frames, 521]
        return s.mean(0); // [521]
      });
      const data = await scores.data();
      scores.dispose();
      const top = (idxs) => idxs.reduce((m, i) => Math.max(m, data[i]), 0);
      latest = {
        speech: top(groups.speech),
        music: top(groups.music),
        instrument: top(groups.instrument),
        clap: top(groups.clap),
        at: Date.now(),
      };
      state = 'on';
    } catch (e) {
      state = 'error';
      errMsg = String(e && e.message || e);
    } finally {
      busy = false;
    }
  }

  async function startInner(instrument) {
    state = 'loading';
    errMsg = '';
    await ensureModel();
    buildGroups(instrument);
    stream = await navigator.mediaDevices.getUserMedia({
      audio: {
        echoCancellation: false,
        noiseSuppression: false, // suppression eats quiet piano notes
        autoGainControl: false,
      },
    });
    const AC = window.AudioContext || window.webkitAudioContext;
    ctx = new AC();
    if (ctx.state === 'suspended') await ctx.resume();
    ring = new Float32Array(Math.round(ctx.sampleRate * 1.5));
    ringLen = ring.length;
    ringPos = 0;
    ringFilled = 0;
    srcNode = ctx.createMediaStreamSource(stream);
    procNode = ctx.createScriptProcessor(4096, 1, 1);
    procNode.onaudioprocess = (e) => pushSamples(e.inputBuffer.getChannelData(0));
    muteNode = ctx.createGain();
    muteNode.gain.value = 0; // keeps the graph running without echoing the mic
    srcNode.connect(procNode);
    procNode.connect(muteNode);
    muteNode.connect(ctx.destination);
    timer = setInterval(classifyOnce, 1000);
  }

  return {
    start(instrument) {
      stopCapture();
      startInner(instrument).catch((e) => {
        state = 'error';
        errMsg = String(e && e.message || e);
        stopCapture(true);
      });
    },
    stop() {
      stopCapture();
    },
    status() {
      return JSON.stringify({
        ready: state === 'on',
        state,
        error: errMsg,
        speech: latest.speech,
        music: latest.music,
        instrument: latest.instrument,
        clap: latest.clap,
        ageMs: latest.at ? Date.now() - latest.at : -1,
      });
    },
  };

  function stopCapture(keepState) {
    if (timer) { clearInterval(timer); timer = null; }
    try { if (procNode) procNode.disconnect(); } catch (_) {}
    try { if (srcNode) srcNode.disconnect(); } catch (_) {}
    try { if (muteNode) muteNode.disconnect(); } catch (_) {}
    try { if (stream) stream.getTracks().forEach((t) => t.stop()); } catch (_) {}
    try { if (ctx) ctx.close(); } catch (_) {}
    procNode = srcNode = muteNode = stream = ctx = null;
    latest = { speech: 0, music: 0, instrument: 0, clap: 0, at: 0 };
    if (!keepState) { state = 'off'; errMsg = ''; }
  }
})();
