function Set-PSModulePath {
    param(
        [String[]]
        $ModuleToLeaveLoaded,

        [String[]]
        $PathsToSet = @()
    )

    if(Get-Module PSDesiredStateConfiguration) {
        Remove-Module -Force PSDesiredStateConfiguration
    }

    $Env:PSModulePath = Join-Path -Path $PShome -ChildPath Modules
    Get-Module | Where-Object { $_.Name -notin $ModuleToLeaveLoaded } | Remove-Module -Force

    $PathsToSet.Foreach{
        if($_ -notin ($Env:PSModulePath -split ';')) {
            $Env:PSModulePath = $_ + ';' + $Env:PSModulePath
        }
    }
}