Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Ensure-Dir {
  param([string]$Path)
  if (-not [string]::IsNullOrWhiteSpace($Path)) {
    $null = New-Item -ItemType Directory -Path $Path -Force -ErrorAction SilentlyContinue
  }
}

function Write-File {
  param(
    [Parameter(Mandatory=$true)][string]$Path,
    [Parameter(Mandatory=$true)][Object]$Content
  )
  Ensure-Dir (Split-Path -Parent $Path)
  Set-Content -Path $Path -Encoding UTF8 -Value $Content
}

function Add-Lines {
  param(
    [Parameter(Mandatory=$true)][string]$Path,
    [Parameter(Mandatory=$true)][Object]$Content
  )
  Ensure-Dir (Split-Path -Parent $Path)
  Add-Content -Path $Path -Encoding UTF8 -Value $Content
}

# Root folders
$homeDir = $env:USERPROFILE
$devRoot = Join-Path $homeDir 'Developer'
$desktop = [Environment]::GetFolderPath('Desktop')

Write-Host "[1/3] Creating $devRoot structure..." -ForegroundColor Cyan
foreach ($d in 'shell','java','python','js','docker','archives','sandbox') {
  Ensure-Dir (Join-Path $devRoot $d)
}

# Optional desktop shortcut (Entwicklung.lnk)
$shortcutPath = Join-Path $desktop 'Entwicklung.lnk'
if (-not (Test-Path $shortcutPath)) {
  try {
    $s = New-Object -ComObject WScript.Shell
    $lnk = $s.CreateShortcut($shortcutPath)
    $lnk.TargetPath = $devRoot
    $lnk.WorkingDirectory = $devRoot
    $lnk.WindowStyle = 1
    $lnk.IconLocation = "$env:SystemRoot\system32\shell32.dll,3"
    $lnk.Save()
    if (Test-Path $shortcutPath) { Write-Host "[i] Desktop shortcut created: $shortcutPath" }
  } catch { }
}

Write-Host "`n[2/3] Collecting project info..." -ForegroundColor Cyan
$projectName = Read-Host '?? New project name (e.g., my-microservice)'
$folder = Read-Host '?? Language/folder (shell/java/python/js/docker/sandbox) [java]'
if ([string]::IsNullOrWhiteSpace($folder)) { $folder = 'java' }
$template = Read-Host '?? Template (none/java-gradle) [java-gradle]'
if ([string]::IsNullOrWhiteSpace($template)) { $template = 'java-gradle' }

$targetDir = Join-Path (Join-Path $devRoot $folder) $projectName

if (-not (Test-Path $targetDir)) {
  Write-Host "[*] Creating project in $targetDir..." -ForegroundColor Green
  Ensure-Dir $targetDir
} else {
  Write-Host "[i] Project already exists at $targetDir" -ForegroundColor Yellow
}

Push-Location $targetDir

# Git init if needed
if (-not (Test-Path .git)) {
  try {
    git init | Out-Null
  } catch { }
  Write-File README.md "# $projectName"
  $gitignore = @(
    '# macOS','.DS_Store','',
    '# Java/Gradle','/build/','/.gradle/','/out/','/bin/','/*.iml','/.idea/','/.vscode/.classpath','/.vscode/.project','',
    '# Logs','*.log'
  )
  Write-File .gitignore $gitignore
  if (-not (Test-Path LICENSE)) { Write-File LICENSE '' }
  Write-Host "[?] Project $projectName initialized with Git in $targetDir" -ForegroundColor Green
}

# Common files
Write-File .editorconfig @(
  'root = true','',
  '[*]','charset = utf-8','end_of_line = lf','insert_final_newline = true','indent_style = space','indent_size = 2','trim_trailing_whitespace = true','',
  '[*.{java,gradle,kts,md,yml,yaml}]','indent_size = 2'
)

Ensure-Dir .vscode
Write-File .vscode\extensions.json @'
{
  "recommendations": [
    "vscjava.vscode-java-pack",
    "richardwillis.vscode-gradle",
    "redhat.vscode-xml",
    "editorconfig.editorconfig"
  ]
}
'@

if ($template -ieq 'java-gradle') {
  $groupId = Read-Host '??  Group ID (default: com.example)'
  if ([string]::IsNullOrWhiteSpace($groupId)) { $groupId = 'com.example' }
  $packageName = Read-Host "?? Package (default: $groupId.app)"
  if ([string]::IsNullOrWhiteSpace($packageName)) { $packageName = "$groupId.app" }
  $javaVer = Read-Host '? Java version (17/21, default: 21)'
  if ([string]::IsNullOrWhiteSpace($javaVer)) { $javaVer = '21' }
  $projType = Read-Host '?? Project type (application/library, default: application)'
  if ([string]::IsNullOrWhiteSpace($projType)) { $projType = 'application' }

  # Directories
  Ensure-Dir 'src/main/java'
  Ensure-Dir 'src/main/resources'
  Ensure-Dir 'src/test/java'

  # Package path
  $pkgPath = $packageName -replace '\.', '/'
  Ensure-Dir ("src/main/java/$pkgPath")
  Ensure-Dir ("src/test/java/$pkgPath")

  # Main or Library
  $mainClass = ''
  if ($projType -ieq 'application') {
    $mainClass = "$packageName.Main"
    Write-File ("src/main/java/$pkgPath/Main.java") @(
      "package $packageName;",
      '',
      'public final class Main',
      '{',
      '  private Main() {}',
      '',
      '  public static void main(String[] args)',
      '  {',
      ('    System.out.println("Hello from {0}!");' -f $projectName),
      '  }',
      '}'
    )
  } else {
    Write-File ("src/main/java/$pkgPath/Library.java") @(
      "package $packageName;",
      '',
      'public class Library',
      '{',
      '  public String greet(String name)',
      '  {',
      '    return "Hello, " + name + "!";',
      '  }',
      '}'
    )
  }

  # JUnit 5 test
  Write-File ("src/test/java/$pkgPath/SampleTest.java") @(
    "package $packageName;",
    '',
    'import org.junit.jupiter.api.Test;',
    'import static org.junit.jupiter.api.Assertions.*;',
    '',
    'class SampleTest {',
    '',
    '  @Test',
    '  void helloTest() {',
    '    assertTrue(1 + 1 == 2, "Math still works");',
    '  }',
    '}'
  )

  # build.gradle
  $lines = @()
  $lines += 'plugins {'
  $lines += "  id 'java'"
  if ($projType -ieq 'application') { $lines += "  id 'application'" }
  $lines += "  id 'checkstyle'"
  $lines += "  id 'com.diffplug.spotless' version '6.25.0'"
  $lines += '}'
  $lines += ''
  $lines += "group = '$groupId'"
  $lines += "version = '0.1.0'"
  $lines += ''
  $lines += 'java {'
  $lines += '  toolchain {'
  $lines += "    languageVersion = JavaLanguageVersion.of($javaVer)"
  $lines += '  }'
  $lines += '}'
  $lines += ''
  $lines += 'repositories {'
  $lines += '  mavenCentral()'
  $lines += '}'
  $lines += ''
  $lines += 'dependencies {'
  $lines += "  testImplementation 'org.junit.jupiter:junit-jupiter:5.11.0'"
  $lines += '}'
  $lines += ''
  $lines += 'checkstyle {'
  $lines += "  toolVersion = '10.17.0'"
  $lines += "  configDirectory = file('config/checkstyle')"
  $lines += '}'
  $lines += ''
  $lines += 'spotless {'
  $lines += '  java {'
  $lines += "    target 'src/**/*.java'"
  $lines += "    // Eclipse JDT formatter for Allman-style braces"
  $lines += "    eclipse().configFile('config/eclipse/eclipse-java-formatter.prefs')"
  $lines += '    removeUnusedImports()'
  $lines += '    formatAnnotations()'
  $lines += '  }'
  $lines += '}'
  $lines += ''
  $lines += 'test {'
  $lines += '  useJUnitPlatform()'
  $lines += '  // Faster unit tests; disable for integration tests'
  $lines += "  jvmArgs '-Xmx512m'"
  $lines += '}'
  $lines += ''
  $lines += 'tasks.withType(JavaCompile).configureEach {'
  $lines += "  options.encoding = 'UTF-8'"
  $lines += "  options.release = $javaVer"
  $lines += '}'
  if ($projType -ieq 'application') {
    $lines += ''
    $lines += 'application {'
    $lines += "  mainClass = '$mainClass'"
    $lines += '}'
  }
  $lines += ''
  $lines += "tasks.register('printEnv') {"
  $lines += "  group = 'help'"
  $lines += "  description = 'Prints Gradle + Java environment details.'"
  $lines += '  doLast {'
  $lines += '    println "Gradle: ${gradle.gradleVersion}"'
  $lines += '    println "Java toolchain: ${java.toolchain.languageVersion.get()}"'
  $lines += '    println "Project: ${project.group}:${project.name}:${project.version}"'
  $lines += '  }'
  $lines += '}'
  Write-File build.gradle $lines

  # settings.gradle
  $slug = ($projectName).ToLower().Replace(' ','-')
  Write-File settings.gradle "rootProject.name = '$slug'"

  # VS Code
  Ensure-Dir .vscode
  Write-File .vscode\tasks.json @'
{
  "version": "2.0.0",
  "tasks": [
    { "label": "Gradle Clean",  "type": "shell", "command": "./gradlew clean",              "group": "build", "problemMatcher": [] },
    { "label": "Gradle Build",  "type": "shell", "command": "./gradlew build -x test",      "group": "build", "problemMatcher": [] },
    { "label": "Gradle Test",   "type": "shell", "command": "./gradlew test",                "problemMatcher": [] },
    { "label": "Run App",       "type": "shell", "command": "./gradlew run",                 "group": "build", "problemMatcher": [] },
    { "label": "Gradle Spotless Apply", "type": "shell", "command": "./gradlew", "args": ["spotlessApply"], "windows": { "command": ".\\gradlew.bat" }, "group": "build", "problemMatcher": [] },
    { "label": "Gradle Checkstyle", "type": "shell", "command": "./gradlew", "args": ["checkstyleMain", "checkstyleTest"], "problemMatcher": [] }
  ]
}
'@

  Write-File .vscode\launch.json @"
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Run Main",
      "type": "java",
      "request": "launch",
      "mainClass": "$mainClass",
      "projectName": "$slug"
    }
  ]
}
"@

  Write-File .vscode\settings.json @'
{
  // Use Red Hat Java formatter by default for Java files
  "editor.defaultFormatter": "redhat.java",

  // Format on save for quick feedback
  "editor.formatOnSave": true,

  // Point VS Code Java to the same Eclipse formatter configuration
  // used by Spotless (the XML variant)
  "java.format.settings.url": "${workspaceFolder}/config/eclipse/eclipse-java-formatter.xml",
  "java.format.settings.profile": "AllmanStyle",

  // Keep line endings in sync with .editorconfig
  "files.eol": "\n",

  // Organize imports automatically on save (Java only)
  "[java]": {
    "editor.codeActionsOnSave": {
      "source.organizeImports": true
    }
  }
}
'@

  # Checkstyle + Eclipse formatter
  Ensure-Dir 'config/checkstyle'
  Ensure-Dir 'config/eclipse'
  Write-File config/checkstyle/checkstyle.xml @(
    '<?xml version="1.0"?>',
    '<!DOCTYPE module PUBLIC',
    '    "-//Checkstyle//DTD Checkstyle Configuration 1.3//EN"',
    '    "config/checkstyle/configuration_1_3.dtd"/>',
    '<module name="Checker">',
    '  <property name="severity" value="warning"/>',
    '',
    '  <module name="TreeWalker">',
    '    <!-- Imports and whitespace hygiene -->',
    '    <module name="UnusedImports"/>',
    '    <module name="NoLineWrap"/>',
    '    <module name="WhitespaceAround"/>',
    '    <module name="WhitespaceAfter"/>',
    '    <module name="NoWhitespaceBefore"/>',
    '    <module name="FileTabCharacter"/>',
    '',
    '    <!-- Braces and layout (Allman style) -->',
    '    <module name="NeedBraces"/>',
    '    <module name="LeftCurly"><property name="option" value="nl"/></module>',
    '    <module name="RightCurly"><property name="option" value="alone"/></module>',
    '',
    '    <!-- Indentation and wrapping -->',
    '    <module name="Indentation">',
    '      <property name="basicOffset" value="2"/>',
    '      <property name="braceAdjustment" value="0"/>',
    '      <property name="caseIndent" value="2"/>',
    '      <property name="lineWrappingIndentation" value="4"/>',
    '      <property name="throwsIndent" value="4"/>',
    '    </module>',
    '    <module name="OperatorWrap"/>',
    '    <module name="LineLength">',
    '      <property name="max" value="120"/>',
    '      <property name="ignorePattern" value="^package|^import|a href|http"/>',
    '    </module>',
    '',
    '    <!-- Naming basics -->',
    '    <module name="LocalVariableName"/>',
    '    <module name="MemberName"/>',
    '    <module name="ParameterName"/>',
    '    <module name="TypeName"/>',
    '  </module>',
    '</module>'
  )

  Write-File config/checkstyle/configuration_1_3.dtd @(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<!ELEMENT module (property*, module*)>',
    '<!ATTLIST module name CDATA #REQUIRED>',
    '<!ELEMENT property EMPTY>',
    '<!ATTLIST property name CDATA #REQUIRED value CDATA #REQUIRED>'
  )

  Write-File config/eclipse/eclipse-java-formatter.prefs @(
    'eclipse.preferences.version=1',
    'org.eclipse.jdt.core.formatter.brace_position_for_type_declaration=next_line',
    'org.eclipse.jdt.core.formatter.brace_position_for_anonymous_type_declaration=next_line',
    'org.eclipse.jdt.core.formatter.brace_position_for_method_declaration=next_line',
    'org.eclipse.jdt.core.formatter.brace_position_for_constructor_declaration=next_line',
    'org.eclipse.jdt.core.formatter.brace_position_for_block=next_line',
    'org.eclipse.jdt.core.formatter.brace_position_for_block_in_case=next_line',
    'org.eclipse.jdt.core.formatter.brace_position_for_switch=next_line',
    'org.eclipse.jdt.core.formatter.brace_position_for_array_initializer=next_line',
    'org.eclipse.jdt.core.formatter.brace_position_for_enum_declaration=next_line',
    'org.eclipse.jdt.core.formatter.brace_position_for_annotation_type_declaration=next_line',
    'org.eclipse.jdt.core.formatter.lineSplit=120',
    'org.eclipse.jdt.core.formatter.tabulation.char=space',
    'org.eclipse.jdt.core.formatter.tabulation.size=2',
    'org.eclipse.jdt.core.formatter.indentation.size=2'
  )

  Write-File config/eclipse/eclipse-java-formatter.xml @'
<?xml version="1.0" encoding="UTF-8"?>
<profiles version="21">
  <profile kind="CodeFormatterProfile" name="AllmanStyle" version="21">
    <setting id="org.eclipse.jdt.core.formatter.brace_position_for_type_declaration" value="next_line"/>
    <setting id="org.eclipse.jdt.core.formatter.brace_position_for_anonymous_type_declaration" value="next_line"/>
    <setting id="org.eclipse.jdt.core.formatter.brace_position_for_method_declaration" value="next_line"/>
    <setting id="org.eclipse.jdt.core.formatter.brace_position_for_constructor_declaration" value="next_line"/>
    <setting id="org.eclipse.jdt.core.formatter.brace_position_for_block" value="next_line"/>
    <setting id="org.eclipse.jdt.core.formatter.brace_position_for_block_in_case" value="next_line"/>
    <setting id="org.eclipse.jdt.core.formatter.brace_position_for_switch" value="next_line"/>
    <setting id="org.eclipse.jdt.core.formatter.brace_position_for_array_initializer" value="next_line"/>
    <setting id="org.eclipse.jdt.core.formatter.brace_position_for_enum_declaration" value="next_line"/>
    <setting id="org.eclipse.jdt.core.formatter.brace_position_for_annotation_type_declaration" value="next_line"/>
    <setting id="org.eclipse.jdt.core.formatter.lineSplit" value="120"/>
    <setting id="org.eclipse.jdt.core.formatter.tabulation.char" value="space"/>
    <setting id="org.eclipse.jdt.core.formatter.tabulation.size" value="2"/>
    <setting id="org.eclipse.jdt.core.formatter.indentation.size" value="2"/>
  </profile>
  </profiles>
'@

  # Gradle wrapper if available
  try {
    if (Get-Command gradle -ErrorAction SilentlyContinue) {
      Write-Host "[i] Generating Gradle Wrapper..."
      & gradle -q wrapper --gradle-version 8.10.2 | Out-Null
    } else {
      Write-Host "[i] Gradle is not installed. Wrapper not generated." -ForegroundColor Yellow
      Write-Host "    Install Gradle and run: gradle wrapper --gradle-version 8.10.2"
    }
  } catch {
    Write-Host "[!] Gradle wrapper generation failed: $($_.Exception.Message)" -ForegroundColor Yellow
  }

  # Git pre-commit hook (sh script)
  Ensure-Dir '.git/hooks'
  Write-File .git/hooks/pre-commit @(
    '#!/bin/sh',
    '# Ensure Spotless formatting before committing',
    'if [ -x "./gradlew" ]; then',
    '  ./gradlew -q spotlessApply || {',
    '    echo "Spotless failed; aborting commit." >&2',
    '    exit 1',
    '  }',
    '  git add -A',
    'else',
    '  echo "gradlew not found; skipping spotlessApply" >&2',
    'fi'
  )
}

Pop-Location

# [3/3] Open in VS Code if available
if (Get-Command code -ErrorAction SilentlyContinue) {
  Write-Host "[*] Opening project in VS Code..."
  Start-Process code $targetDir | Out-Null
} else {
  Write-Host "[i] VS Code CLI ('code') not found. In VS Code, run: Shell Command: Install 'code' command in PATH" -ForegroundColor Yellow
}

Write-Host 'Done.' -ForegroundColor Green
