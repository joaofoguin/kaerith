@echo off
rem Publica a versao Web exportada (pasta site) no Firebase Hosting.
rem Antes: exporte no Godot pelo preset Web (ele salva em hospedagem\site\index.html).
cd /d "%~dp0"
if not exist "site\index.html" (
  echo Falta exportar: no Godot, Projeto ^> Exportar ^> Web ^> Exportar projeto.
  pause
  exit /b 1
)
rem paginas fixas do site (politica de privacidade etc.); o Godot nao mexe nelas
xcopy /y /q "paginas\*" "site\" >nul
rem service worker do Kaerith (atualiza sem quebrar o offline): troca o do Godot e ganha um numero de versao novo
powershell -NoProfile -Command "$v = Get-Date -Format 'yyyyMMddHHmmss'; $f = 'site\index.service.worker.js'; (Get-Content $f -Raw -Encoding UTF8) -replace '__VERSAO__', $v | Set-Content $f -NoNewline -Encoding UTF8"
findstr /c:"__VERSAO__" "site\index.service.worker.js" >nul && (echo Nao consegui marcar a versao do service worker. & pause & exit /b 1)
call firebase deploy --only hosting
pause
