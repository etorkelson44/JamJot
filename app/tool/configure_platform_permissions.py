"""Run after `flutter create . --platforms web,ios,android` (idempotent)."""
from pathlib import Path
import plistlib
import xml.etree.ElementTree as ET

app = Path(__file__).resolve().parents[1]
info = app / 'ios/Runner/Info.plist'
if info.exists():
    data = plistlib.loads(info.read_bytes())
    data['NSMicrophoneUsageDescription'] = 'JamJot uses the microphone to record your music practice and count time with sound.'
    info.write_bytes(plistlib.dumps(data, sort_keys=False))
manifest = app / 'android/app/src/main/AndroidManifest.xml'
if manifest.exists():
    namespace = 'http://schemas.android.com/apk/res/android'
    ET.register_namespace('android', namespace)
    tree = ET.parse(manifest)
    root = tree.getroot()
    for permission in ('RECORD_AUDIO', 'MODIFY_AUDIO_SETTINGS', 'INTERNET'):
        name = f'android.permission.{permission}'
        if not any(e.get(f'{{{namespace}}}name') == name for e in root.findall('uses-permission')):
            ET.SubElement(root, 'uses-permission', {f'{{{namespace}}}name': name})
    tree.write(manifest, encoding='utf-8', xml_declaration=True)
