/// Shows a sheet-music file inside the practice screen.
/// On the web, PDFs render in an embedded frame; images render inline.
export 'score_frame_stub.dart'
    if (dart.library.js_interop) 'score_frame_web.dart';
