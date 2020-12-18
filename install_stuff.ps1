#Tested in one of the Hyper-V templates
#Run First: Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
#Run as admin

$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://github.com/git-for-windows/git/releases/download/v2.29.2.windows.2/Git-2.29.2.2-64-bit.exe",(Get-Location).tostring()+"\git.exe")
$proc = Start-Process -FilePath .\git.exe -ArgumentList "/SILENT"

$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://chocolatey.org/install.ps1",(Get-Location).tostring()+"\install_choco.ps1")

$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://download.visualstudio.microsoft.com/download/pr/1206a800-42a6-4dd5-8b7d-27ccca92e823/cf739d701898f888a4c0b49722791e5ff450d40c6a986f69ecfb1e4da384e126/vs_BuildTools.exe",(Get-Location).tostring()+"\vs_BuildTools.exe")
$proc = Start-Process -FilePath vs_BuildTools.exe -ArgumentList "--passive", "--add", "Microsoft.VisualStudio.Workload.VCTools", "--includeRecommended", "--wait" -Wait -PassThru

.\install_choco.ps1
choco install cmake --installargs ADD_CMAKE_TO_PATH=System -y
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
choco install 7zip -y
choco install python -y
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")

git clone --recurse-submodules https://github.com/YosysHQ/prjtrellis.git
git clone https://github.com/YosysHQ/yosys.git
git clone https://github.com/YosysHQ/nextpnr.git
git clone https://github.com/YosysHQ/icestorm.git


$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://dl.bintray.com/boostorg/release/1.73.0/source/boost_1_73_0.zip",(Get-Location).tostring()+"\boost_1_73_0.7z")
set-alias sz "$env:ProgramFiles\7-Zip\7z.exe"
sz x ".\boost_1_73_0.7z"

& {
"C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvarsamd64_x86.bat"
cd boost_1_73_0
.\bootstrap.bat
# Python wants the shared versions so lets do those
# CMake seems to want to find both when creating project files even if we only use one
.\b2 link=shared runtime-link=shared variant=release
.\b2 link=shared runtime-link=shared variant=debug
}

Copy-Item -Recurse "boost" -Destination "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\VS\include"
Copy-Item -Recurse "stage\lib\*" -Destination "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\VS\lib\x64"

Copy-Item -Recurse "boost" -Destination "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\VS\include"
Copy-Item -Recurse "stage\lib\*" -Destination "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\VS\lib\x64"

cd ..

[Environment]::SetEnvironmentVariable("Boost_INCLUDEDIR", "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\VS\include", [System.EnvironmentVariableTarget]::Machine)
[Environment]::SetEnvironmentVariable("Boost_LIBRARYDIR", "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\VS\lib\x64", [System.EnvironmentVariableTarget]::Machine)
$env:Boost_INCLUDEDIR = [System.Environment]::GetEnvironmentVariable("BOOST_INCLUDEDIR", "Machine")
$env:Boost_LIBRARYDIR = [System.Environment]::GetEnvironmentVariable("Boost_LIBRARYDIR", "Machine")

$oldpath = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH).path
$newpath = $oldpath + ";"+(Get-Location).tostring()+"\boost_1_73_0\stage\lib"
Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH -Value $newPath
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")

cd .\prjtrellis\libtrellis\
cmake -DCMAKE_CXX_FLAGS='/D "BOOST_ALL_DYN_LINK"' .
."C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\MSBuild\Current\Bin\MSBuild.exe" /t:Build /p:Configuration=Release /p:VCTargetsPath="C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\MSBuild\Microsoft\VC\v160\\" libtrellis.sln

$releaseDir="C:\Users\User\Desktop\OSS-FPGA"
$msysReleaseDir="/c/Users/User/Desktop/OSS-FPGA"
mkdir $releaseDir
cmake -DCMAKE_INSTALL_PREFIX="$releaseDir" -DBUILD_TYPE=Release -P cmake_install.cmake

cd ..\..

git clone https://github.com/microsoft/vcpkg.git
cd vcpkg
.\bootstrap-vcpkg.bat
.\vcpkg.exe install qt5-base:x64-windows eigen3:x64-windows
.\vcpkg.exe integrate install
cd ..

choco install llvm -y

[Environment]::SetEnvironmentVariable("PYTHONPATH", "C:\Users\User\Desktop\prjtrellis\util\common;C:\Users\User\Desktop\prjtrellis\timing\util", [System.EnvironmentVariableTarget]::Machine)
$env:PYTHONPATH = [System.Environment]::GetEnvironmentVariable("PYTHONPATH", "Machine")

cd nextpnr
cmake . -DCMAKE_TOOLCHAIN_FILE="C:/Users/User/Desktop/vcpkg/scripts/buildsystems/vcpkg.cmake"  -DCMAKE_CXX_FLAGS='/D "BOOST_ALL_DYN_LINK" /D "WIN32" /EHsc' -DARCH=ecp5 -DCMAKE_PREFIX_PATH="C:\Users\User\Desktop\prjtrellis\libtrellis\Release"
."C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\MSBuild\Current\Bin\MSBuild.exe" /t:Build /p:Configuration=Release /p:Platform=x64 /p:VCTargetsPath="C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\MSBuild\Microsoft\VC\v160\\" nextpnr.sln
cmake -DCMAKE_INSTALL_PREFIX="$releaseDir" -DBUILD_TYPE=Release -P cmake_install.cmake
cd ..

#http://grbd.github.io/posts/2016/09/12/setting-up-the-icestorm-fpga-tools-for-windows/

choco install msys2 -y
refreshenv

C:\tools\msys64\msys2_shell.cmd -defterm -no-start -c "pacman --noconfirm -Syuu"
#C:\tools\msys64\msys2_shell.cmd -defterm -no-start -c "pacman --noconfirm -S mingw64/mingw-w64-x86_64-clang"
C:\tools\msys64\msys2_shell.cmd -defterm -no-start -c "pacman --noconfirm -S msys/bison"
C:\tools\msys64\msys2_shell.cmd -defterm -no-start -c "pacman --noconfirm -S msys/flex"
C:\tools\msys64\msys2_shell.cmd -defterm -no-start -c "pacman --noconfirm -S msys/libreadline-devel"
C:\tools\msys64\msys2_shell.cmd -defterm -no-start -c "pacman --noconfirm -S msys/gawk"
C:\tools\msys64\msys2_shell.cmd -defterm -no-start -c "pacman --noconfirm -S msys/tcl"
C:\tools\msys64\msys2_shell.cmd -defterm -no-start -c "pacman --noconfirm -S msys/libffi-devel"
C:\tools\msys64\msys2_shell.cmd -defterm -no-start -c "pacman --noconfirm -S git"
C:\tools\msys64\msys2_shell.cmd -defterm -no-start -c "pacman --noconfirm -S cmake"
C:\tools\msys64\msys2_shell.cmd -defterm -no-start -c "pacman --noconfirm -S mercurial"
C:\tools\msys64\msys2_shell.cmd -defterm -no-start -c "pacman --noconfirm -S msys/pkg-config"
C:\tools\msys64\msys2_shell.cmd -defterm -no-start -c "pacman --noconfirm -S python"
C:\tools\msys64\msys2_shell.cmd -defterm -no-start -c "pacman --noconfirm -S pacman -S python3"
C:\tools\msys64\msys2_shell.cmd -defterm -no-start -c "pacman --noconfirm -S mingw64/mingw-w64-x86_64-libftdi"
C:\tools\msys64\msys2_shell.cmd -defterm -no-start -c "pacman --noconfirm -S mingw64/mingw-w64-x86_64-python3-pip"
C:\tools\msys64\msys2_shell.cmd -defterm -no-start -c "pacman --noconfirm -S mingw64/mingw-w64-x86_64-python2-pip"
C:\tools\msys64\msys2_shell.cmd -defterm -no-start -c "pacman --noconfirm -S mingw64/mingw-w64-x86_64-dlfcn"
C:\tools\msys64\msys2_shell.cmd -defterm -no-start -c "pacman --noconfirm -S mingw-w64-x86_64-toolchain"

C:\tools\msys64\msys2_shell.cmd -defterm -no-start -c "MSYSTEM=MINGW64 . /etc/profile && pip2 install xdot"
C:\tools\msys64\msys2_shell.cmd -defterm -no-start -c "MSYSTEM=MINGW64 . /etc/profile && pip3 install xdot"


C:\tools\msys64\msys2_shell.cmd -defterm -no-start -c "MSYSTEM=MINGW64 . /etc/profile && cd /c/Users/User/Desktop/icestorm && mingw32-make PREFIX=/usr -j4"

C:\tools\msys64\msys2_shell.cmd -defterm -no-start -c "MSYSTEM=MINGW64 . /etc/profile && cd /c/Users/User/Desktop/yosys && mingw32-make config-msys2-64"
C:\tools\msys64\msys2_shell.cmd -defterm -no-start -c "MSYSTEM=MINGW64 . /etc/profile && cd /c/Users/User/Desktop/yosys && mingw32-make -j8"
C:\tools\msys64\msys2_shell.cmd -defterm -no-start -c "MSYSTEM=MINGW64 . /etc/profile && cd /c/Users/User/Desktop/yosys && mingw32-make DESTDIR=$msysReleaseDir PREFIX='' install"


Copy-Item -Recurse "boost_1_73_0\stage\lib\*x64*.dll" -Destination $releaseDir"\bin"

# yosys, might need a better way to figure out what files to copy over
# install to folders then copy the contents? Especially the share folder?
Copy-Item -Recurse "C:\tools\msys64\mingw64\bin\tcl86.dll" -Destination $releaseDir"\bin"
Copy-Item -Recurse "C:\tools\msys64\mingw64\bin\libgcc_s_seh-1.dll" -Destination $releaseDir"\bin"
Copy-Item -Recurse "C:\tools\msys64\mingw64\bin\zlib1.dll" -Destination $releaseDir"\bin"
Copy-Item -Recurse "C:\tools\msys64\mingw64\bin\libreadline8.dll" -Destination $releaseDir"\bin"
Copy-Item -Recurse "C:\tools\msys64\mingw64\bin\libstdc++-6.dll" -Destination $releaseDir"\bin"
Copy-Item -Recurse "C:\tools\msys64\mingw64\bin\libwinpthread-1.dll" -Destination $releaseDir"\bin"
Copy-Item -Recurse "C:\tools\msys64\mingw64\bin\libtermcap-0.dll" -Destination $releaseDir"\bin"
Copy-Item -Recurse "nextpnr\Release\*" -Destination $releaseDir"\bin"

Compress-Archive "$releaseDir\*" "OSS-FPGA.zip"