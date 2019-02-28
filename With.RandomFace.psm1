Add-type -AssemblyName "system.drawing"
gci "$PSScriptRoot\Function" -Filter "*.public.ps1"|%{
    . $_.FullName
}