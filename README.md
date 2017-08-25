# CollectDumps

This PowerShell script will collect process dumps and zip in a single file. A URL for this file will be provided on the script's conclusion.

## Using CollectDumps:

.\CollectDumpsPlus.ps1 [-personal <personal_environment_name>]

### Examples

- Default usage

  .\CollectDumpsPlus.ps1

- Include application pools' dumps from a specific personal environment named OHKZ70022

  .\CollectDumpsPlus.ps1 -personal OHKZ70022


## By default this script will include the following:

- DeployService dumps;
- CompilerService dumps;
- SandboxManager dumps;
- LogServer dumps;
- Scheduler dumps;
- Event viewer Application logs;
- clr.dll;
- mscordacwks.dll;
- SOS.dll;
- mscordbi.dll;
- SandboxManager.log;
- Personal environment application pools dumps [optional]
