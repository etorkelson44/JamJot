import 'package:web/web.dart' as web;

bool get printingSupported => true;

/// Opens the browser's print dialog (where "Save as PDF" also lives).
void printPage() {
  web.window.print();
}
