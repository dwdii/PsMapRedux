#
# Module manifest for module 'PsMapRedux'
#
# Generated by: Daniel Dittenhafer
#
# Generated on: March 27 2012
#

@{

# Script module or binary module file associated with this manifest
ModuleToProcess = 'PsMapRedux.psm1'

# Version number of this module.
ModuleVersion = '1.0'

# ID used to uniquely identify this module
GUID = '5805CFF0-729C-4858-B0D9-58E539CDDE1A'

# Author of this module
Author = 'Daniel Dittenhafer'

# Company or vendor of this module
CompanyName = 'Dittenhafer Solutions'

# Copyright statement for this module
Copyright = '(c) 2011-2012 Dittenhafer Solutions. All rights reserved.'

# Description of the functionality provided by this module
Description = 'This module provides a simple framework for the MapReduce distributed computing framework on Windows PowerShell.'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '2.0'

# Name of the Windows PowerShell host required by this module
PowerShellHostName = ''

# Minimum version of the Windows PowerShell host required by this module
PowerShellHostVersion = ''

# Minimum version of the .NET Framework required by this module
DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module
CLRVersion = ''

# Processor architecture (None, X86, Amd64, IA64) required by this module
ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
RequiredModules = @()

# Assemblies that must be loaded prior to importing this module
RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module
ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
FormatsToProcess = @()

# Modules to import as nested modules of the module specified in ModuleToProcess
NestedModules = @()

# Functions to export from this module
FunctionsToExport = "New-MapReduxItem", "Invoke-MapRedux"

# Cmdlets to export from this module
CmdletsToExport = '*'

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module
AliasesToExport = '*'

# List of all files packaged with this module
FileList = @()

# Private data to pass to the module specified in ModuleToProcess
PrivateData = ''

}
