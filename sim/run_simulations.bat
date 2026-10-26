@echo off
echo =====================================================================
echo  Running Full ModelSim / QuestaSim Regression Suite for L2 Cache
echo =====================================================================

set VSIM_PATH=C:\intelFPGA\20.1\modelsim_ase\win32aloem\vsim.exe
if not exist "%VSIM_PATH%" (
    set VSIM_PATH=C:\intelFPGA\22.1std\questa_fse\win64\vsim.exe
)
if not exist "%VSIM_PATH%" (
    where vsim.exe >nul 2>&1
    if %ERRORLEVEL% equ 0 (
        set VSIM_PATH=vsim.exe
    )
)

echo Using Simulation Tool: %VSIM_PATH%
"%VSIM_PATH%" -c -do "do run_sim.do; quit -f"

echo =====================================================================
echo  Simulation Suite Finished! Check transcript above.
echo =====================================================================
pause
