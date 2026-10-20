# PowerShell Helper Script for Windows Terminal
param (
    [string]$Target = "all"
)

$WsPath = "/mnt/c/Users/dipan/OneDrive/Documents/Asynchronous FIFO"

switch ($Target.ToLower()) {
    "basic" {
        Write-Host "[RUNNING] Basic Smoke Test..." -ForegroundColor Cyan
        wsl -d Ubuntu -e bash -c "cd '$WsPath' && make -f sim/Makefile basic"
    }
    "advanced" {
        Write-Host "[RUNNING] 15-Scenario Advanced Stress Suite..." -ForegroundColor Cyan
        wsl -d Ubuntu -e bash -c "cd '$WsPath' && make -f sim/Makefile advanced"
    }
    "all" {
        Write-Host "[RUNNING] All Test Suites (Basic + Advanced)..." -ForegroundColor Cyan
        wsl -d Ubuntu -e bash -c "cd '$WsPath' && make -f sim/Makefile all"
    }
    "waves" {
        Write-Host "[LAUNCHING] GTKWave Viewer in Background..." -ForegroundColor Green
        Start-Process wsl -ArgumentList "-d", "Ubuntu", "-e", "bash", "-c", "cd '$WsPath' && DISPLAY=:0 gtkwave waves/dump_basic.vcd"
    }
    default {
        Write-Host "Usage: .\sim\run.ps1 [basic | advanced | all | waves]" -ForegroundColor Yellow
    }
}
