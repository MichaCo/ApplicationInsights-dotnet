$generatorPath = "C:\src\mseng\AppInsights-Common"
$schemasPath = "C:\src\mseng\DataCollectionSchemas"




function RegExReplace([string]$fileName, [string]$regex, [string]$replacement="")
{
    $tempFileName = $fileName + ".temp"
    [IO.File]::ReadAllText($fileName) -creplace $regex,$replacement | Set-Content $tempFileName
    copy $tempFileName $fileName
    del $tempFileName
}

#fix path
$generatorPath = "$generatorPath\..\bin\Debug\BondSchemaGenerator\BondSchemaGenerator"
$schemasPath = "$schemasPath\v2\Bond\"

& "$generatorPath\BondSchemaGenerator.exe" -v -i "$schemasPath\AppInsightsTypes.bond" -i "$schemasPath\ContextTagKeys.bond" -o ".\PublicSchema\" -e BondLanguage -t BondLayout -n test --flatten false

& ..\nuget install Bond.CSharp -Version 4.2.1 -OutputDirectory .\packages


dir .\PublicSchema | ForEach-Object { 
    & .\packages\Bond.CSharp.4.2.1\tools\gbc.exe c# --collection-interfaces --using="DateTimeOffset=System.DateTimeOffset" --using="TimeSpan=System.TimeSpan" --using="Guid=System.Guid" -o ".\gbc" $_.FullName
}

del .\gbc\*_interfaces.cs
del .\gbc\*_services.cs
del .\gbc\*_proxies.cs

dir .\gbc | ForEach-Object { 
    # Rename namespace from AI to Microsoft.ApplicationInsights.Extensibility.Implementation.External
    RegExReplace $_.FullName "(namespace AI)" "namespace Microsoft.ApplicationInsights.Extensibility.Implementation.External"
    # Remove "using Bond" statements
    RegExReplace $_.FullName "using Bond.*"
    # Remove all Bond attributes
    RegExReplace $_.FullName "\[global::Bond\..*\]"
    # Remove derivations from Microsoft.Telemetry.Domain
    RegExReplace $_.FullName ":\s*global::Microsoft\.Telemetry\.Domain"
    # Replace IBonded field definition with plain type field definition
    RegExReplace $_.FullName "global::Bond\.IBonded<([A-Za-z0-9_]+)>" '$1'
    # Remove the baseData field initializer
    RegExReplace $_.FullName "baseData\s*=.*;"
    # Remove the data field initializer
    RegExReplace $_.FullName "data\s*=.*;"
    # Make all public classes internal
    RegExReplace $_.FullName "(public partial class)" "internal partial class"
    # Make all public enums internal
    RegExReplace $_.FullName "(public enum)" "internal enum"
    # Change "= nothing" to "= null"
    RegExReplace $_.FullName "= nothing;" "= null;"
}

@(
"Base_types",
"ContextTagKeys_types",
"DataPointType_types",
"DataPoint_types",
"Data_types",
"Domain_types",
"Envelope_types",
"EventData_types",
"ExceptionData_types",
"ExceptionDetails_types",
"MessageData_types",
"MetricData_types",
"PageViewData_types",
"RemoteDependencyData_types",
"RequestData_types",
"SeverityLevel_types",
"StackFrame_types",
"TestResult_types"
) | ForEach-Object { 
    $fileName = $_
    copy ".\gbc\$fileName.cs" "..\src\Core\Managed\Shared\Extensibility\Implementation\External\"
}

