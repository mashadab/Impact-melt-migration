param(
    [ValidateScript({ $_ -gt 0 -and -not [double]::IsInfinity($_) -and -not [double]::IsNaN($_) })]
    [double]$Kc = 1.85e-8,
    [string]$MatlabPath = 'C:/Program Files/MATLAB/R2022b/bin/matlab.exe',
    [string]$OutputDirectory = '',
    [switch]$PrepareOnly
)
# Launch the corrected impact_melt_europa switch from a frozen source tree.
$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$commit = & git -c "safe.directory=$repoRoot" -C $repoRoot rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw 'Cannot record the Git revision.' }
$trackedChanges = & git -c "safe.directory=$repoRoot" -C $repoRoot status --porcelain --untracked-files=no
if ($trackedChanges) { throw 'Commit the tracked source changes before starting a research run.' }
if (-not (Test-Path -LiteralPath $MatlabPath -PathType Leaf)) { throw 'MATLAB executable not found.' }
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
if (-not $OutputDirectory) {
    $kcLabel = $Kc.ToString('0.000e+00', [Globalization.CultureInfo]::InvariantCulture)
    $OutputDirectory = Join-Path $repoRoot "Output/Europa_S3_corrected_kc_${kcLabel}_${stamp}"
}
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $OutputDirectory) { throw 'Choose a new output directory; existing runs are preserved.' }
$runtimeRoot = Join-Path $OutputDirectory 'runtime'
$frozenSource = Join-Path $runtimeRoot 'model_and_dependencies'
$frozenInput = Join-Path $runtimeRoot 'initial_conditions'
New-Item -ItemType Directory -Path $frozenSource,$frozenInput | Out-Null
$records = @()
$sourceFiles = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'model_and_dependencies') -File -Filter '*.m')
foreach ($file in $sourceFiles) {
    $target = Join-Path $frozenSource $file.Name
    Copy-Item -LiteralPath $file.FullName -Destination $target
    $originalHash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $frozenHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($originalHash -ne $frozenHash) { throw "Source copy differs: $($file.Name)" }
    $records += [ordered]@{ path="model_and_dependencies/$($file.Name)"; sha256=$frozenHash }
}
$inputFile = Join-Path $repoRoot 'initial_conditions/ic03321_100.mat'
$inputTarget = Join-Path $frozenInput 'ic03321_100.mat'
Copy-Item -LiteralPath $inputFile -Destination $inputTarget
$inputHash = (Get-FileHash -LiteralPath $inputTarget -Algorithm SHA256).Hash.ToLowerInvariant()
if ($inputHash -ne (Get-FileHash -LiteralPath $inputFile -Algorithm SHA256).Hash.ToLowerInvariant()) { throw 'Input copy differs.' }
$records += [ordered]@{ path='initial_conditions/ic03321_100.mat'; sha256=$inputHash }
$provenance = [ordered]@{
    git_commit=$commit.Trim(); created_local=(Get-Date -Format o)
    case_key='impact_melt_europa'; kc_m2=$Kc; permeability_exponent=3
    eta0_Pa_s=1e14; activation_energy_J_mol=50000; impact_key='03321'
    correct_head_reference=$true; use_actual_conductivity_timestep=$true
    lower_initial_phi=0; lower_initial_temperature_K=273; impermeable_base=$true
    stop_remaining_shell_fraction=0.005; runtime_root=$runtimeRoot
    executable_solver=(Join-Path $frozenSource 'darcy_stokes_2D_cases.m')
    source_files=$records
}
$provenance | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'launch_provenance.json') -Encoding utf8
function ConvertTo-MatlabLiteral([string]$value) { return $value.Replace('\','/').Replace("'","''") }
$matlabSource = ConvertTo-MatlabLiteral $frozenSource
$matlabOut = ConvertTo-MatlabLiteral $OutputDirectory
$matlabKc = $Kc.ToString('G17',[Globalization.CultureInfo]::InvariantCulture)
$launchCode = @"
addpath('$matlabSource','-begin');
assert(strcmp(strrep(which('darcy_stokes_2D_cases'),'\','/'),'$matlabSource/darcy_stokes_2D_cases.m'));
assert(strcmp(strrep(which('run_darcy_stokes_case'),'\','/'),'$matlabSource/run_darcy_stokes_case.m'));
for name={'darcy_stokes_2D_cases.m','run_darcy_stokes_case.m','run_Europa_until_depleted.m'}
 messages=checkcode(fullfile('$matlabSource',name{1}),'-id');
 assert(~any(strcmp({messages.id},'PARSE')),'Parse error in %s',name{1});
end
try
 o=struct('kc',$matlabKc,'initial_only',true,'save_state_snapshots',true, ...
  'output_dir',fullfile('$matlabOut','initial_check'));
 initial=run_darcy_stokes_case('impact_melt_europa',o);
 assert(initial.permeability_exponent==3 && initial.correct_head_reference && initial.use_actual_conductivity_timestep);
 assert(strcmp(initial.Grid.p.geom,'cylindrical_rz') && isequal(initial.mesh,[100 120]));
 [~,z]=meshgrid(initial.Grid.p.xc,initial.Grid.p.yc);
 assert(all(initial.final_state.phi(z(:)<0)==0));
 assert(all(abs(initial.final_state.T_dimensionless(z(:)<0)*173+100-273)<1e-10));
 verification=struct('passed',true,'case_key',initial.case_key,'nn',initial.permeability_exponent, ...
  'kc_m2',initial.kc,'initial_shell_melt_km3',initial.initial_shell_melt_m3/1e9, ...
  'executable',which('darcy_stokes_2D_cases'),'git_commit','$($commit.Trim())');
 fid=fopen(fullfile('$matlabOut','startup_verification.json'),'w');fprintf(fid,'%s',jsonencode(verification));fclose(fid);
 clear initial;
 run_Europa_until_depleted('$matlabOut',$matlabKc);
 plot_Europa_latest_results('$matlabOut');
catch exception
 fid=fopen(fullfile('$matlabOut','LAUNCH_FAILED.txt'),'w');fprintf(fid,'%s',getReport(exception,'extended','hyperlinks','off'));fclose(fid);
 rethrow(exception)
end
"@
$launchFile = Join-Path $OutputDirectory 'start_Europa_S3.m'
Set-Content -LiteralPath $launchFile -Value $launchCode -Encoding utf8
$matlabLaunch = ConvertTo-MatlabLiteral $launchFile
$arguments = '-batch "run(''' + $matlabLaunch + ''')"'
if ($PrepareOnly) {
    [ordered]@{ output_dir=$OutputDirectory; git_commit=$commit.Trim(); kc_m2=$Kc; case_key='impact_melt_europa'; launch_file=$launchFile; status='queued' } | ConvertTo-Json -Compress
    return
}
$process = Start-Process -FilePath $MatlabPath -ArgumentList $arguments -WorkingDirectory $repoRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $OutputDirectory 'matlab_stdout.log') -RedirectStandardError (Join-Path $OutputDirectory 'matlab_stderr.log')
$launch = [ordered]@{ process_id=$process.Id; output_dir=$OutputDirectory; git_commit=$commit.Trim(); kc_m2=$Kc; case_key='impact_melt_europa' }
$launch | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $OutputDirectory 'launch.json') -Encoding utf8
$pointerDirectory = Join-Path $repoRoot 'tmp'
New-Item -ItemType Directory -Path $pointerDirectory -Force | Out-Null
Set-Content -LiteralPath (Join-Path $pointerDirectory 'Europa_S3_latest_run.txt') -Value $OutputDirectory -Encoding utf8
$launch | ConvertTo-Json -Compress
