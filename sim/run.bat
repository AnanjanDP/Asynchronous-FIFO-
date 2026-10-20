@echo off
set WSPATH=/mnt/c/Users/dipan/OneDrive/Documents/Asynchronous FIFO

if "%1"=="basic" (
    wsl -d Ubuntu -e bash -c "cd '%WSPATH%' && make -f sim/Makefile basic"
) else if "%1"=="advanced" (
    wsl -d Ubuntu -e bash -c "cd '%WSPATH%' && make -f sim/Makefile advanced"
) else if "%1"=="waves" (
    start wsl -d Ubuntu -e bash -c "cd '%WSPATH%' && DISPLAY=:0 gtkwave waves/dump_basic.vcd"
) else (
    wsl -d Ubuntu -e bash -c "cd '%WSPATH%' && make -f sim/Makefile all"
)
