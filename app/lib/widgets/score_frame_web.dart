import 'dart:convert';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

final Set<String> _registered = {};

/// Web: embed the sheet music right in the practice screen.
///
/// PDFs get our own little viewer (pdf.js) so the behavior is the same in
/// every browser — Safari included, where a plain PDF iframe shows only a
/// corner of the page: the WHOLE page always fits the box, and multi-page
/// pieces get ◀ 1 / 3 ▶ arrows. Anything else falls back to a plain frame.
Widget buildScoreFrame(String url) {
  final isPdf = url.split('?').first.toLowerCase().endsWith('.pdf');
  final viewType = 'jamjot-score-${isPdf ? 'pdf' : 'raw'}-${url.hashCode}';
  if (!_registered.contains(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
      final el =
          web.document.createElement('iframe') as web.HTMLIFrameElement;
      el.style.border = 'none';
      el.style.width = '100%';
      el.style.height = '100%';
      if (isPdf) {
        el.srcdoc = _pdfViewerHtml(url).toJS;
      } else {
        el.src = url;
      }
      return el;
    });
    _registered.add(viewType);
  }
  return HtmlElementView(viewType: viewType);
}

String _pdfViewerHtml(String url) {
  final u = jsonEncode(url); // safely quoted for the script
  return '''
<!doctype html><html><head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  html,body{margin:0;height:100%;background:#fff;overflow:hidden;
    font-family:-apple-system,system-ui,sans-serif}
  #wrap{position:relative;width:100%;height:100%;
    display:flex;align-items:center;justify-content:center}
  canvas{display:block}
  #nav{position:absolute;bottom:8px;left:50%;transform:translateX(-50%);
    background:rgba(26,26,46,.85);color:#fff;border-radius:999px;
    padding:2px 6px;display:none;gap:4px;align-items:center;user-select:none}
  #nav button{background:none;border:none;color:#fff;font-size:17px;
    cursor:pointer;padding:4px 10px}
  #nav span{font-size:13px;min-width:44px;text-align:center}
  #err{display:none;padding:20px;color:#666;text-align:center}
</style></head><body>
<div id="wrap"><canvas id="c"></canvas>
<div id="nav"><button id="prev">&#9664;</button><span id="label"></span><button id="next">&#9654;</button></div>
<div id="err">Could not display the music here — tap and hold to open it.</div>
</div>
<script src="https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js"></script>
<script>
var url=$u, pdf=null, page=1, busy=false, again=false;
function render(){
  if(!pdf)return;
  if(busy){again=true;return;}
  busy=true;
  pdf.getPage(page).then(function(p){
    var dpr=window.devicePixelRatio||1;
    var v=p.getViewport({scale:1});
    var fit=Math.min(innerWidth/v.width, innerHeight/v.height);
    var vp=p.getViewport({scale:fit*dpr});
    var c=document.getElementById('c');
    c.width=vp.width; c.height=vp.height;
    c.style.width=(vp.width/dpr)+'px'; c.style.height=(vp.height/dpr)+'px';
    p.render({canvasContext:c.getContext('2d'),viewport:vp}).promise
      .then(done).catch(done);
    document.getElementById('label').textContent=page+' / '+pdf.numPages;
  }).catch(done);
  function done(){busy=false; if(again){again=false; render();}}
}
try{
  pdfjsLib.GlobalWorkerOptions.workerSrc=
    'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js';
  pdfjsLib.getDocument(url).promise.then(function(d){
    pdf=d;
    if(d.numPages>1)document.getElementById('nav').style.display='flex';
    render();
  }).catch(function(){document.getElementById('err').style.display='block';});
}catch(e){document.getElementById('err').style.display='block';}
document.getElementById('prev').onclick=function(){if(page>1){page--;render();}};
document.getElementById('next').onclick=function(){if(pdf&&page<pdf.numPages){page++;render();}};
var rt; addEventListener('resize',function(){clearTimeout(rt);rt=setTimeout(render,150);});
</script></body></html>
''';
}
