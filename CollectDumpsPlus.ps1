param(	[string]$personal = '', [switch]$enterprise)
Add-Type -Path "C:\Program Files (x86)\Reference Assemblies\Microsoft\Framework\.NETFramework\v4.5\System.IO.Compression.FileSystem.dll"

function ZipFiles( $zipfilename, $sourcedir )
{
   Add-Type -Assembly System.IO.Compression.FileSystem
   $compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
   [System.IO.Compression.ZipFile]::CreateFromDirectory($sourcedir,
        $zipfilename, $compressionLevel, $false)
}

function Expand-ZIPFile($file, $destination)
{
	$shell = new-object -com shell.application
	$zip = $shell.NameSpace($file)
	foreach($item in $zip.items())
	{
		$shell.Namespace($destination).copyhere($item)
	}
}

function Export-EventLog($logName,$destination)
{
   $eventLogSession = New-Object System.Diagnostics.Eventing.Reader.EventLogSession
   $eventLogSession.ExportLogAndMessages($logName,"LogName","*",$destination)
}


# Inform the user if app pools dumps will be included
if ($personal) {Write-Host Dumps for personal $personal application pools will be included} elseif ($enterprise) {Write-Host Dumps for the application pools will be included} else {Write-Host No application pool will be included}

# Retrieve personal application pools PIDs
$appcmdPath = 'C:\windows\system32\inetsrv\appcmd.exe'

if ($personal){
	$apppool_system = $personal + '_System'
	$apppool_apps = $personal + '_Apps'
} elseif ($enterprise) {
	$apppool_system = 'ServiceCenterAppPool'
	$apppool_apps = 'OutSystemsApplications'
}


$system_pid = Invoke-Expression "$appcmdPath list wp /apppool.name:`"$apppool_system`""
if ($system_pid -match "\d+") {$system_pid=$matches[0] }

$apps_pid = Invoke-Expression "$appcmdPath list wp /apppool.name:`"$apppool_apps`""
if ($apps_pid -match "\d+") {$apps_pid=$matches[0] }



$basepath = split-path $SCRIPT:MyInvocation.MyCommand.Path -parent

$url = "https://download.sysinternals.com/files/Procdump.zip"
$output = "$basepath\Procdump.zip"

(New-Object System.Net.WebClient).DownloadFile($url, $output)

Expand-ZIPFile -file $output -destination $basepath

1..3 | ForEach-Object -process {
	.\procdump.exe -ma -accepteula DeployService.exe
	.\procdump.exe -ma -accepteula CompilerService.exe
	.\procdump.exe -ma -accepteula SandboxManager.exe
	.\procdump.exe -ma -accepteula LogServer.exe
	.\procdump.exe -ma -accepteula Scheduler.exe
	
	if ($personal) {
		.\procdump.exe -ma -accepteula $system_pid sysapppool_$_.dmp
		.\procdump.exe -ma -accepteula $apps_pid appsapppool_$_.dmp	
	}
	
	if ($_ -lt 3) { Start-Sleep -s 60 }
}

New-Item -path $basepath\dumps -type directory

Move-Item -path $basepath\*.dmp -destination dumps\

Copy-Item -Path "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\clr.dll" -destination dumps\
Copy-Item -Path "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\mscordacwks.dll" -destination dumps\
Copy-Item -Path "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\SOS.dll" -destination dumps\
Copy-Item -Path "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\mscordbi.dll" -destination dumps\
Copy-Item -Path "C:\Program Files\OutSystems\SandboxManager\SandboxManager.log" -destination dumps\

Export-EventLog -logName "Application" -destination $basepath\dumps\EventLog_Application.evtx 

$date_tag = Get-Date -format 'yyyymmdd_hh\hmm\m'
$final_filename = $env:computername + "_" + $date_tag + "_dumps.zip"
ZipFiles -zipfilename $basepath\$final_filename -sourcedir $basepath\dumps

Move-Item -path $basepath\$final_filename -destination C:\inetpub\wwwroot

$Acl = Get-Acl C:\inetpub\wwwroot\$final_filename
$Ar = New-Object system.security.accesscontrol.filesystemaccessrule("Everyone","FullControl","Allow")
$Acl.SetAccessRule($Ar)
Set-Acl C:\inetpub\wwwroot\$final_filename $Acl

Remove-Item * -include procdump* -force
Remove-Item Eula.txt
Remove-Item dumps -recurse

$siteURL = Get-WebBinding -Name "Default Web Site" -Port 80 -Protocol http | ForEach-Object {$_.bindingInformation.split(':')[2]} | Where-Object {$_ -Match ".*outsystemscloud.*" -or $_ -Match ".*outsystemsenterprise.*"}

Write-Host Download the dumps located at http://$siteURL/$final_filename
Write-Host "Press any key to continue ..."

$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")