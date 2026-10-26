@echo off
title ModelSim L2 BDI Cache Top - Summary Verification Waveform (Ready for PDF Export)
echo =====================================================================
echo       ModelSim Summary Waveform Launcher: tb_l2_bdi_cache_top
echo       Author: Mohammed Gweaa | University of Tripoli
echo       Features: 17 Tests Summary Tracker, STLF, BDI Profiles & Power
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

echo Launching ModelSim GUI with Summary Waveform (Total Time: 5070 ns)...
start "" "%VSIM_EXE%" -do "do wave_comprehensive_summary.do"

echo.
echo =====================================================================
echo   INSTRUCTIONS TO EXPORT TO PDF IN MODELSIM:
echo   1. In ModelSim Wave Window, click File -> Print...
echo   2. Printer: Choose 'Microsoft Print to PDF'
echo   3. Click Properties / Page Setup -> Select Paper: 'A3' or 'Tabloid'
echo   4. Orientation: 'Landscape' (Horizontal)
echo   5. Click OK to Save PDF!
echo =====================================================================
pause
