param(
	[Int32]$buildNumber=0,
	[String]$branchName="localBuild",
	[String]$gitCommitHash="unknownHash",
	[Switch]$isMainBranch=$False)

cls

# '[p]sake' is the same as 'psake' but $Error is not polluted
remove-module [p]sake

# find psake's path
$psakeModule = (Get-ChildItem (".\Packages\psake*\tools\psake.psm1")).FullName | Sort-Object $_ | select -last 1

$psakeScript = (Get-ChildItem (".\Packages\Domain.Build.Scripts*\tools\default.ps1")).FullName | Sort-Object $_ | select -last 1
 
Import-Module $psakeModule

# you can write statements in multiple lines using `
Invoke-psake -buildFile $psakeScript `
			 -taskList FullBuild `
			 -framework 4.6 `
		     -properties @{ 
				 "buildConfiguration" = "Release"
				 "buildPlatform" = "Any CPU"} `
			 -parameters @{ 
				 "solutionFile" = Resolve-Path(".\domain-build-samples.sln")
				 "outputDirectoryName" = "BuildOutput"
				 "buildNumber" = $buildNumber
				 "branchName" = $branchName
				 "gitCommitHash" = $gitCommitHash
				 "isMainBranch" = $isMainBranch}

Write-Host "Build exit code:" $LastExitCode

# Propagating the exit code so that builds actually fail when there is a problem
exit $LastExitCode