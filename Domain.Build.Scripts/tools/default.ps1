Include ".\helpers.ps1"

properties {
	$solutionDirectory = (Get-Item $solutionFile).DirectoryName
	$outputDirectory= "$solutionDirectory\$outputDirectoryName"
	$temporaryOutputDirectory = "$outputDirectory\temp"

	$publishedNUnitTestsDirectory = "$temporaryOutputDirectory\_PublishedNUnitTests"
	$publishedxUnitTestsDirectory = "$temporaryOutputDirectory\_PublishedxUnitTests"
	$publishedMSTestTestsDirectory = "$temporaryOutputDirectory\_PublishedMSTestTests"
	$publishedWebsitesDirectory = "$temporaryOutputDirectory\_PublishedWebsites"
	$publishedApplicationsDirectory = "$temporaryOutputDirectory\_PublishedApplications"
	$publishedDotNetCoreApplicationsDirectory = "$temporaryOutputDirectory\_PublishedDotNetCoreApplications"
	$publishedLibrariesDirectory = "$temporaryOutputDirectory\_PublishedLibraries\"

	$testResultsDirectory = "$outputDirectory\TestResults"
	$NUnitTestResultsDirectory = "$testResultsDirectory\NUnit"
	$xUnitTestResultsDirectory = "$testResultsDirectory\xUnit"
	$MSTestTestResultsDirectory = "$testResultsDirectory\MSTest"

	$testCoverageDirectory = "$outputDirectory\TestCoverage"
	$testCoverageReportPath = "$testCoverageDirectory\OpenCover.xml"
	$testCoverageFilter = "+[*]* -[xunit.*]* -[*.NUnitTests]* -[*.Tests]* -[*.xUnitTests]*"
	$testCoverageExcludeByAttribute = "*.ExcludeFromCodeCoverage*"
	$testCoverageExcludeByFile = "*\*Designer.cs;*\*.g.cs;*\*.g.i.cs"

	$packagesOutputDirectory = "$outputDirectory\Packages"
	$librariesOutputDirectory = "$packagesOutputDirectory\Libraries"
	$applicationsOutputDirectory = "$packagesOutputDirectory\Applications"

	$buildConfiguration = "Release"
	$buildPlatform = "Any CPU"

	$packagesPath = "$solutionDirectory\packages"
	$NUnitExe = (Find-PackagePath $packagesPath "NUnit.Runners") + "\Tools\nunit-console-x86.exe"
	$xUnitExe = (Find-PackagePath $packagesPath "xUnit.Runner.Console") + "\Tools\xunit.console.exe"
	$vsTestExe = (Get-ChildItem ("C:\Program Files (x86)\Microsoft Visual Studio*\Common7\IDE\CommonExtensions\Microsoft\TestWindow\vstest.console.exe")).FullName | Sort-Object $_ | select -last 1
	$openCoverExe = (Find-PackagePath $packagesPath "OpenCover") + "\Tools\OpenCover.Console.exe"
	$reportGeneratorExe = (Find-PackagePath $packagesPath "ReportGenerator") + "\Tools\ReportGenerator.exe"
	$7ZipExe = (Find-PackagePath $packagesPath "7-Zip.CommandLine" ) + "\Tools\7za.exe"
	$nugetExe = (Find-PackagePath $packagesPath "NuGet.CommandLine" ) + "\Tools\NuGet.exe"
}

task default -depends FullBuild

FormatTaskName "`r`n`r`n-------- Executing {0} Task --------"

task Init `
	-description "Initialises the build by removing previous artifacts and creating output directories" `
	-requiredVariables outputDirectory, temporaryOutputDirectory `
{
	Assert ("Debug", "Release" -contains $buildConfiguration) `
		   "Invalid build configuration '$buildConfiguration'. Valid values are 'Debug' or 'Release'"

	Assert ("x86", "x64", "Any CPU" -contains $buildPlatform) `
		   "Invalid build platform '$buildPlatform'. Valid values are 'x86', 'x64' or 'Any CPU'"

	Assert ($outputDirectoryName -ne $null) "The parameter 'outputDirectoryName' needs to be provided"

	# Check that all tools are available
	Write-Host "Checking that all required tools are available"

	Assert (Test-Path $7ZipExe) "7-Zip Command Line could not be found"
	Assert (Test-Path $nugetExe) "NuGet Command Line could not be found"
	
	# Remove previous build results
	if (Test-Path $outputDirectory) 
	{
		Write-Host "Removing output directory located at $outputDirectory"
		Remove-Item $outputDirectory -Force -Recurse
	}

	Write-Host "Creating output directory located at $outputDirectory"
	New-Item $outputDirectory -ItemType Directory | Out-Null

	Write-Host "Creating temporary output directory located at $temporaryOutputDirectory" 
	New-Item $temporaryOutputDirectory -ItemType Directory | Out-Null
}
 
task Compile `
	-depends Init `
	-description "Compile the code" `
	-requiredVariables solutionFile, buildConfiguration, buildPlatform, temporaryOutputDirectory `
{
	#disabled until nuget commandline 3.5.0 is out
	#Write-Host "Restoring NuGet packages for solution `"$solutionFile`"" 
	#Exec { &$nugetExe restore $solutionFile }
	
	Write-Host "Building solution $solutionFile"

	Exec { msbuild $SolutionFile "/p:Configuration=$buildConfiguration;Platform=$buildPlatform;OutDir=$temporaryOutputDirectory;NuGetExePath=$nugetExe" }
}

task TestNUnit `
	-depends Compile `
	-description "Run NUnit tests" `
	-precondition { return (Test-Path $publishedNUnitTestsDirectory) -and (Test-Path $NUnitExe) } `
	-requiredVariable publishedNUnitTestsDirectory, NUnitTestResultsDirectory `
{
	$testAssemblies = Prepare-Tests -testRunnerName "NUnit" `
									-publishedTestsDirectory $publishedNUnitTestsDirectory `
									-testResultsDirectory $NUnitTestResultsDirectory `
									-testCoverageDirectory $testCoverageDirectory

	$targetArgs = "$testAssemblies /xml:`"`"$NUnitTestResultsDirectory\NUnit.xml`"`" /nologo /noshadow"

	# Run OpenCover, which in turn will run NUnit	
	Run-Tests -openCoverExe $openCoverExe `
			  -targetExe $nunitExe `
			  -targetArgs $targetArgs `
			  -coveragePath $testCoverageReportPath `
			  -filter $testCoverageFilter `
			  -excludebyattribute:$testCoverageExcludeByAttribute `
			  -excludebyfile: $testCoverageExcludeByFile
}

task TestXUnit `
	-depends Compile `
	-description "Run xUnit tests" `
	-precondition { return (Test-Path $publishedxUnitTestsDirectory) -and (Test-Path $xUnitExe) } `
	-requiredVariable publishedxUnitTestsDirectory, xUnitTestResultsDirectory `
{
	$testAssemblies = Prepare-Tests -testRunnerName "xUnit" `
									-publishedTestsDirectory $publishedxUnitTestsDirectory `
									-testResultsDirectory $xUnitTestResultsDirectory `
									-testCoverageDirectory $testCoverageDirectory

	$targetArgs = "$testAssemblies -xml `"`"$xUnitTestResultsDirectory\xUnit.xml`"`" -nologo -noshadow"

	# Run OpenCover, which in turn will run xUnit	
	Run-Tests -openCoverExe $openCoverExe `
			  -targetExe $xunitExe `
			  -targetArgs $targetArgs `
			  -coveragePath $testCoverageReportPath `
			  -filter $testCoverageFilter `
			  -excludebyattribute:$testCoverageExcludeByAttribute `
			  -excludebyfile: $testCoverageExcludeByFile
}

task TestMSTest `
	-depends Compile `
	-description "Run MSTest tests" `
	-precondition { return (Test-Path $publishedMSTestTestsDirectory) -and (Test-Path $vsTestExe) } `
	-requiredVariable publishedMSTestTestsDirectory, MSTestTestResultsDirectory `
{
	$testAssemblies = Prepare-Tests -testRunnerName "MSTest" `
									-publishedTestsDirectory $publishedMSTestTestsDirectory `
									-testResultsDirectory $MSTestTestResultsDirectory `
									-testCoverageDirectory $testCoverageDirectory

	$targetArgs = "$testAssemblies /Logger:trx"

	# vstest console doesn't have any option to change the output directory
	# so we need to change the working directory
	Push-Location $MSTestTestResultsDirectory
	
	# Run OpenCover, which in turn will run VSTest	
	Run-Tests -openCoverExe $openCoverExe `
			  -targetExe $vsTestExe `
			  -targetArgs $targetArgs `
			  -coveragePath $testCoverageReportPath `
			  -filter $testCoverageFilter `
			  -excludebyattribute:$testCoverageExcludeByAttribute `
			  -excludebyfile: $testCoverageExcludeByFile

	Pop-Location

	# move the .trx file back to $MSTestTestResultsDirectory
	Move-Item -path $MSTestTestResultsDirectory\TestResults\*.trx -destination $MSTestTestResultsDirectory\MSTest.trx

	Remove-Item $MSTestTestResultsDirectory\TestResults
}

task Test `
	-depends Compile, TestNUnit, TestXUnit, TestMSTest `
	-description "Run unit tests and test coverage" `
	-precondition { return (Test-Path $openCoverExe) -and (Test-Path $reportGeneratorExe) } `
	-requiredVariables testCoverageDirectory, testCoverageReportPath `
{
	# parse OpenCover results to extract summary
	if (Test-Path $testCoverageReportPath)
	{
		Write-Host "Parsing OpenCover results"

		# Load the coverage report as XML
		$coverage = [xml](Get-Content -Path $testCoverageReportPath)

		$coverageSummary = $coverage.CoverageSession.Summary

		# Write class coverage
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsCCovered' value='$($coverageSummary.visitedClasses)']"
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsCTotal' value='$($coverageSummary.numClasses)']"
		Write-Host ("##teamcity[buildStatisticValue key='CodeCoverageC' value='{0:N2}']" -f (($coverageSummary.visitedClasses / $coverageSummary.numClasses)*100))

		# Report method coverage
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsMCovered' value='$($coverageSummary.visitedMethods)']"
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsMTotal' value='$($coverageSummary.numMethods)']"
		Write-Host ("##teamcity[buildStatisticValue key='CodeCoverageM' value='{0:N2}']" -f (($coverageSummary.visitedMethods / $coverageSummary.numMethods)*100))
		
		# Report branch coverage
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsBCovered' value='$($coverageSummary.visitedBranchPoints)']"
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsBTotal' value='$($coverageSummary.numBranchPoints)']"
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageB' value='$($coverageSummary.branchCoverage)']"

		# Report statement coverage
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsSCovered' value='$($coverageSummary.visitedSequencePoints)']"
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsSTotal' value='$($coverageSummary.numSequencePoints)']"
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageS' value='$($coverageSummary.sequenceCoverage)']"

		# Generate HTML test coverage report
		Write-Host "`r`nGenerating HTML test coverage report"
		Exec { &$reportGeneratorExe $testCoverageReportPath $testCoverageDirectory }
	}
	else
	{
		Write-Host "No coverage file found at: $testCoverageReportPath"
	}
}

task Package `
	-depends Compile, Test `
	-description "Package applications" `
	-requiredVariables publishedWebsitesDirectory, publishedApplicationsDirectory, publishedDotNetCoreApplicationsDirectory, applicationsOutputDirectory, publishedLibrariesDirectory, librariesOutputDirectory `
{
	# Merge published websites and published applications
	$applications = $null
	
	if (Test-Path $publishedWebsitesDirectory)
	{
		$applications += @(Get-ChildItem $publishedWebsitesDirectory)
	}

	if (Test-Path $publishedApplicationsDirectory)
	{
		$applications += @(Get-ChildItem $publishedApplicationsDirectory)
	}

	if (Test-Path $publishedDotNetCoreApplicationsDirectory)
	{
		$applications += @(Get-ChildItem $publishedDotNetCoreApplicationsDirectory)
	}

	if ($applications.Length -gt 0 -and !(Test-Path $applicationsOutputDirectory))
	{
		New-Item $applicationsOutputDirectory -ItemType Directory | Out-Null
	}

	foreach($application in $applications)
	{
		$nuspecPath = $application.FullName + "\" + $application.Name + ".nuspec"

		Write-Host "Looking for nuspec file at $nuspecPath"

		if (Test-Path $nuspecPath)
		{
			Write-Host "Packaging $($application.Name) as a NuGet package"

			# Load the nuspec file as XML
			$nuspec = [xml](Get-Content -Path $nuspecPath)
			$metadata = $nuspec.package.metadata

			# Edit the metadata
			$metadata.version = $metadata.version.Replace("[buildNumber]", $buildNumber)

			if(! $isMainBranch)
			{
				# NuGet doesn't support pre-release versions longer than 20 characters
				if ($branchName.Length -gt 20) 
				{ 
					$metadata.version = "$($metadata.version)-$($branchName.Substring(0,20))" 
				} 
				else 
				{ 
					$metadata.version = $metadata.version + "-$branchName" 
				}
			}
			
			$metadata.releaseNotes = "Build Number: $buildNumber`r`nBranch Name: $branchName`r`nCommit Hash: $gitCommitHash"

			# Save the nuspec file
			$nuspec.Save((Get-Item $nuspecPath))

			# package as NuGet package
			exec { & $nugetExe pack $nuspecPath -OutputDirectory $applicationsOutputDirectory -verbosity normal -NoPackageAnalysis}
		}
		else
		{
			Write-Host "Packaging $($application.Name) as a zip file"

			$inputDirectory = "$($application.FullName)\*"
			$archivePath = "$($applicationsOutputDirectory)\$($application.Name).zip"

			Exec { & $7ZipExe a -r -mx3 $archivePath $inputDirectory }
		}

		#Moving NuGet libraries to the packages directory
		if (Test-Path $publishedLibrariesDirectory)
		{
			if (!(Test-Path $librariesOutputDirectory))
			{
				Mkdir $librariesOutputDirectory | Out-Null
			}

			Get-ChildItem -Path $publishedLibrariesDirectory -Filter "*.nupkg" -Recurse | Move-Item -Destination $librariesOutputDirectory
		}
	}
}

task Clean `
	-depends Compile, Test, Package `
	-description "Remove temporary files" `
	-requiredVariables temporaryOutputDirectory `
{ 
	if (Test-Path $temporaryOutputDirectory) 
	{
		Write-Host "Removing temporary output directory located at $temporaryOutputDirectory"

		Remove-Item $temporaryOutputDirectory -force -Recurse
	}
}

task FullBuild `
	-depends Compile, Test, Package, Clean `
	-description "Full build"