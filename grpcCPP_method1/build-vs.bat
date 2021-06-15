@echo off

call :prepare_env
call :build_vs

goto :EOF

:prepare_env

echo "call env.bat if exist"
if exist env.bat (call env.bat)

goto :EOF

:build_vs

if exist build (echo "build folder exist.") else (md build)
cd build/

cmake ../ -DCMAKE_TOOLCHAIN_FILE="%WATCH_VCPKG_DIR%/scripts/buildsystems/vcpkg.cmake"
cd ../

goto :EOF