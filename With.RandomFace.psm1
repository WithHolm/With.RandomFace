gci "$PSScriptRoot\Function" -Filter "*.public.ps1"|%{
    . $_.FullName
}