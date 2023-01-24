$global:TempDir = "$env:BuildScriptPath/temp"
$global:DownloadsDir = "$TempDir/downloads"
$global:DependentsDir = "$TempDir/dependents"
$global:SourcesDir = "$TempDir/sources"
$global:InstallDir = "$TempDir/install"

$global:PatchsDir = "$env:BuildScriptPath/patchs"

$global:BuildDir = "$env:BuildScriptPath/build"
$global:BuildArchDirs = @{ 
    "amd64" = "$BuildDir/amd64"
    "x86" = "$BuildDir/x86"
    "arm64" = "$BuildDir/arm64"
    "arm" = "$BuildDir/arm"
}

$global:PerlVersion = "5.32.1.1"
$global:PerlSha1Amd64 = "075b5f77eb862a1ca6d83065662b36749bc39788"
$global:PerlSha1X86 = "2b37527d2038731ab9d32ab24a8bb11c116dd60a"

$global:NasmVersion = "2.16.01"
$global:NasmSha1Amd64 = "412520F192224715FB91D643F9640CE1005CAB99"
$global:NasmSha1X86 = "412520F192224715FB91D643F9640CE1005CAB99"

$global:CMakeVersion = "3.25.1"
$global:CMakeSha1Amd64 = "4AD98D3AE9833767051C16C9D120C10BCE539EE8"
$global:CMakeSha1X86 = "1CD087D80C1400F1BBEB4366CB66F3AEB30518BB"

$global:Msys2Version = "2022-12-16"
$global:Msys2Sha1 = "919B44849F246FAD3C3F500B9A23853522A895BB"


$global:Pkcs11HelperVersion = "1.29.0"
$global:Pkcs11HelperSourceSha1 = "969BC06FA88DC39BAB894DDB557080B8CAFF24B3"

$global:LzoVersion = "2.10"
$global:LzoSourceSha1 = "4924676a9bae5db58ef129dc1cebce3baa3c4b5d"

$global:Lz4Version = "1.9.4"

$global:OpensslVersion = "3.0.7"

$global:TongsuoVersion = "8.3.2"

$global:VsWherePath = "${env:ProgramFiles(x86)}/Microsoft Visual Studio/Installer/vswhere.exe"