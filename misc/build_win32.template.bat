@echo off

set SRC_DIR=tags/release-x.x.x
set BUILD_TYPE=Release
set BUILD_DIR=build_x.x.x

C:
cd \hndev\holdingnuts
echo Updating source tree
echo.
svn up


rmdir /q /s %BUILD_DIR%
mkdir %BUILD_DIR%
cd %BUILD_DIR%


echo.
echo Configuring for %SRC_DIR% (%BUILD_TYPE%)
echo.


cmake -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=%BUILD_TYPE% -DUSE_SVNREV=On ..\%SRC_DIR%


echo.
echo Building %SRC_DIR% (%BUILD_TYPE%)
echo.

mingw32-make


echo.
echo Finished. Check the results!
echo.

pause
