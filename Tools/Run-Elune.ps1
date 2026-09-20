param(
    [Parameter(Mandatory = $true)]
    [string]$Script,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
)

$lua = 'C:\dev\elune-bin\elune-3.1-windows-amd64\bin\lua.exe'

if (-not (Test-Path -LiteralPath $lua -PathType Leaf)) {
    throw "Elune was not found at $lua. Install the Windows release from https://github.com/Meorawr/elune/releases."
}

if (-not (Test-Path -LiteralPath $Script -PathType Leaf)) {
    throw "Lua script was not found: $Script"
}

& $lua $Script @Arguments
exit $LASTEXITCODE