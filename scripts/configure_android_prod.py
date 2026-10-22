from pathlib import Path
import re

path = Path('android/app/build.gradle.kts')
if not path.exists():
    raise SystemExit('android/app/build.gradle.kts não encontrado. Rode flutter create antes.')

s = path.read_text()

# Add imports once
imports = 'import java.util.Properties\nimport java.io.FileInputStream\n\n'
if 'import java.util.Properties' not in s:
    s = imports + s

# Load key.properties before android block
loader = '''val keystoreProperties = Properties()\nval keystorePropertiesFile = rootProject.file("key.properties")\nif (keystorePropertiesFile.exists()) {\n    keystoreProperties.load(FileInputStream(keystorePropertiesFile))\n}\n\n'''
if 'val keystoreProperties = Properties()' not in s:
    s = s.replace('android {', loader + 'android {', 1)

# Fixed namespace/application ID
s = re.sub(r'namespace\s*=\s*"[^"]+"', 'namespace = "com.arcoanalytics.app"', s)
s = re.sub(r'applicationId\s*=\s*"[^"]+"', 'applicationId = "com.arcoanalytics.app"', s)

# Add release signing config before buildTypes if absent
signing = '''    signingConfigs {\n        create("release") {\n            keyAlias = keystoreProperties["keyAlias"] as String\n            keyPassword = keystoreProperties["keyPassword"] as String\n            storeFile = keystoreProperties["storeFile"]?.let { file(it) }\n            storePassword = keystoreProperties["storePassword"] as String\n        }\n    }\n\n'''
if 'create("release")' not in s:
    s = s.replace('    buildTypes {', signing + '    buildTypes {', 1)

# Replace template debug signing on release with release key
s = re.sub(
    r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)',
    'signingConfig = signingConfigs.getByName("release")',
    s,
)

path.write_text(s)
print('Android configurado com applicationId com.arcoanalytics.app e assinatura release.')
