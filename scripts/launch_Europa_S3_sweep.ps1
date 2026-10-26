param(
    [double[]]$KcValues = @(1.85e-10,1.85e-12,1.85e-14),
    [string]$MatlabPath = 'C:/Program Files/MATLAB/R2022b/bin/matlab.exe',
    [string]$PythonPath = 'C:/Users/lenovo/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe',
    [string]$SweepDirectory = '',
    [switch]$Worker
)
# Sequential queue around the existing frozen-source research launcher.
# Solver equations, initial conditions and material/thermal boundaries are unchanged.
$ErrorActionPreference = 'Stop'
function Save-Queue($record,[string]$path) {
    $record.updated_local = Get-Date -Format o
    $record | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath ($path+'.partial') -Encoding utf8
    Move-Item -LiteralPath ($path+'.partial') -Destination $path -Force
}
if ($Worker) {
    $queueFile = Join-Path $SweepDirectory 'queue.json'
    $queue = Get-Content -LiteralPath $queueFile -Raw | ConvertFrom-Json
    $queue.worker_pid = $PID
    $queue.status = 'running'
    Save-Queue $queue $queueFile
    try {
        foreach ($case in $queue.cases) {
            $case.status = 'starting'
            $case.started_local = Get-Date -Format o
            Save-Queue $queue $queueFile
            $launchFile = $case.launch_file.Replace('\','/').Replace("'","''")
            $arguments = '-batch "run('''+$launchFile+''')"'
            $process = Start-Process -FilePath $queue.matlab_path -ArgumentList $arguments -WorkingDirectory $queue.repo_root -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $case.output_dir 'matlab_stdout.log') -RedirectStandardError (Join-Path $case.output_dir 'matlab_stderr.log')
            $case.process_id = $process.Id
            $case | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $case.output_dir 'launch.json') -Encoding utf8
            $case.status = 'running'
            Save-Queue $queue $queueFile
            Set-Content -LiteralPath (Join-Path $queue.repo_root 'tmp/Europa_S3_latest_run.txt') -Value $case.output_dir -Encoding utf8
            # Wait only in this detached queue worker; the chat remains responsive.
            $exporter = $null
            do {
                if (-not $exporter -and (Test-Path -LiteralPath (Join-Path $case.output_dir 'run_configuration.json'))) {
                    $exportArgs = '"'+(Join-Path $SweepDirectory 'preserve_Europa_paper_outputs.py')+'" "'+$case.output_dir+'" --watch'
                    $exporter = Start-Process -FilePath $queue.python_path -ArgumentList $exportArgs -WorkingDirectory $queue.repo_root -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $case.output_dir 'paper_exporter_stdout.log') -RedirectStandardError (Join-Path $case.output_dir 'paper_exporter_stderr.log')
                    $case.exporter_pid = $exporter.Id
                    Save-Queue $queue $queueFile
                }
                Start-Sleep -Seconds 5
                $process.Refresh()
            } while (-not $process.HasExited)
            $process.WaitForExit()
            $case.exit_code = $process.ExitCode
            $case.finished_local = Get-Date -Format o
            if ((Test-Path -LiteralPath (Join-Path $case.output_dir 'COMPLETE.txt')) -and $case.exit_code -eq 0) {
                $case.status = 'completed'
                $case.summary = Get-Content -LiteralPath (Join-Path $case.output_dir 'summary.json') -Raw | ConvertFrom-Json
            } else {
                $case.status = 'failed'
            }
            Save-Queue $queue $queueFile
        }
        $queue.status = if (@($queue.cases | Where-Object status -ne 'completed').Count) { 'finished_with_failures' } else { 'completed' }
        Save-Queue $queue $queueFile
    } catch {
        $queue.status = 'failed'
        $queue.error = $_.ToString()
        Save-Queue $queue $queueFile
        throw
    }
    return
}
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
if (-not $KcValues.Count -or @($KcValues | Where-Object { $_ -le 0 -or [double]::IsInfinity($_) -or [double]::IsNaN($_) }).Count) { throw 'Kc values must be finite and positive.' }
if (@($KcValues | Select-Object -Unique).Count -ne $KcValues.Count) { throw 'Duplicate permeability cases.' }
foreach ($executable in @($MatlabPath,$PythonPath)) {
    if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) { throw "Executable not found: $executable" }
}
$pointer = Join-Path $repoRoot 'tmp/Europa_S3_latest_sweep.txt'
if (Test-Path -LiteralPath $pointer) {
    $previous = Join-Path ((Get-Content -LiteralPath $pointer -Raw).Trim()) 'queue.json'
    if (Test-Path -LiteralPath $previous) {
        $prior = Get-Content -LiteralPath $previous -Raw | ConvertFrom-Json
        if ($prior.status -in @('queued','running') -and $prior.worker_pid -and (Get-Process -Id $prior.worker_pid -ErrorAction SilentlyContinue)) { throw 'A sweep worker is already running.' }
    }
}
if (-not $SweepDirectory) { $SweepDirectory = Join-Path $repoRoot ('Output/Europa_S3_sweep_'+(Get-Date -Format 'yyyyMMdd_HHmmss')) }
$SweepDirectory = [IO.Path]::GetFullPath($SweepDirectory)
if (Test-Path -LiteralPath $SweepDirectory) { throw 'Choose a fresh sweep directory.' }
New-Item -ItemType Directory -Path $SweepDirectory | Out-Null
$cases = @()
foreach ($kc in $KcValues) {
    $label = $kc.ToString('0.000e+00',[Globalization.CultureInfo]::InvariantCulture)
    $prepared = & (Join-Path $PSScriptRoot 'launch_Europa_S3_research.ps1') -Kc $kc -MatlabPath $MatlabPath -OutputDirectory (Join-Path $SweepDirectory "kc_$label") -PrepareOnly | ConvertFrom-Json
    $cases += [ordered]@{ kc_m2=$kc; status='queued'; output_dir=$prepared.output_dir; launch_file=$prepared.launch_file; git_commit=$prepared.git_commit; process_id=$null; exporter_pid=$null; started_local=$null; finished_local=$null; exit_code=$null; summary=$null }
}
$queue = [ordered]@{ status='queued'; created_local=(Get-Date -Format o); updated_local=$null; worker_pid=$null; repo_root=$repoRoot; matlab_path=$MatlabPath; python_path=$PythonPath; case_key='impact_melt_europa'; nn=3; remaining_shell_fraction=0.005; concurrent_simulations=1; cases=$cases; error=$null }
Save-Queue $queue (Join-Path $SweepDirectory 'queue.json')
Copy-Item -LiteralPath $PSCommandPath -Destination (Join-Path $SweepDirectory 'run_queue.ps1')
Copy-Item -LiteralPath (Join-Path $repoRoot 'model_and_dependencies/preserve_Europa_paper_outputs.py') -Destination (Join-Path $SweepDirectory 'preserve_Europa_paper_outputs.py')
$powershellPath = (Get-Process -Id $PID).Path
$arguments = '-NoProfile -File "'+(Join-Path $SweepDirectory 'run_queue.ps1')+'" -Worker -SweepDirectory "'+$SweepDirectory+'"'
$workerProcess = Start-Process -FilePath $powershellPath -ArgumentList $arguments -WorkingDirectory $repoRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $SweepDirectory 'queue_stdout.log') -RedirectStandardError (Join-Path $SweepDirectory 'queue_stderr.log')
Set-Content -LiteralPath $pointer -Value $SweepDirectory -Encoding utf8
[ordered]@{ sweep_dir=$SweepDirectory; worker_pid=$workerProcess.Id; kc_values=$KcValues; queue_file=(Join-Path $SweepDirectory 'queue.json') } | ConvertTo-Json -Compress
