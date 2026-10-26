@echo off
title ModelSim L2 BDI Cache Regression Suite
echo =====================================================================
echo       ModelSim Simulation Launcher: Full L2 Cache Regression Suite
echo       Author: Mohammed Adel Gweaa | University of Tripoli
echo =====================================================================
echo.

set VSIM_EXE=C:\intelFPGA\20.1\modelsim_ase\win32aloem\vsim.exe
if not exist "%VSIM_EXE%" (
    set VSIM_EXE=C:\intelFPGA\22.1std\questa_fse\win64\vsim.exe
)
if not exist "%VSIM_EXE%" (
    where vsim.exe >nul 2>&1
    if %ERRORLEVEL% equ 0 (
        set VSIM_EXE=vsim.exe
    )
)

echo Changing directory to sim ...
cd /d "%~dp0sim"

echo Launching ModelSim GUI with Complete Hierarchical Waveform (17 Scenarios)...
start "" "%VSIM_EXE%" -do "do wave_l2_bdi_cache_top.do"

echo Done. ModelSim GUI is running.
