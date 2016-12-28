#==============
# psinatra.ps1
#==============
[console]::TreatControlCAsInput = $true

$_routers = @{}
$global:_req   = $null
$global:_param = $null
$global:_res   = $null

function get($path, $block) {
  $_routers["GET " + $path] = $block
}

function post($path, $block) {
  $_routers["POST " + $path] = $block
}

function get_routers {
  $_routers
}

function _coalesce($a, $b) { if ($a -ne $null) { $a } else { $b } }
new-alias "??" _coalesce -force

function _write($res, [hashtable]$hash = @{}) {
  $headers = ?? $hash["headers"] @{}
  $headers.keys | % {
    $res.headers.add($_, $headers[$_])
  }
  
  $res.StatusCode = ?? $hash["code"] 200
  $body = ?? $hash["body"] ""
  $buffer = [System.Text.Encoding]::utf8.GetBytes($body)
  $stream = $res.outputstream
  $stream.write($buffer, 0, $buffer.length)
  $stream.close()
}

function _write_text($res, $text) {
  _write -res $res -hash @{ body = $text }
}

function run($bind = "localhost", [int]$port = 9999) {
  if (-not [system.net.httplistener]::IsSupported) {
    write-host "http listener is not supported" -f red
    exit
  }

  $binding = "http://$($bind):$($port)"
  try {
    $server = new-object -type system.net.httplistener
    $server.prefixes.add("$binding/")
  }
  catch {
    write-host "cannot open listening at $binding" -f red
    exit
  }

  $server.start()
  write-host "Sinatra is started on $binding" -f cyan

  while($server.IsListening) {
    if ([console]::KeyAvailable) {
      $key = [system.console]::readkey($true)
      if (($key.modifiers -band [consolemodifiers]"control") -and ($key.key -eq "C"))
      {  
        write-host "Sinatra is leaving the stage..." -f yellow
        break
      }
    }

    $_context      = $server.GetContext()
    $global:_req   = $_context.Request
    $global:_res   = $_context.Response
    $global:_param = $_req.QueryString

    try {
      $key = $_req.HttpMethod + " " + $_req.Url.AbsolutePath

      # match url
      # TODO: to match more complex urls
      if ($_routers.keys -contains $key) {
        $_b = $_routers[$key]
        if ($_b -isnot "scriptblock") {
          write-host "no block defined for $key" -f red
          exit
        }

        # execute block
        try {
          $_block_result = $_b.Invoke()[-1]
        }
        catch {
          write-host $_.exception.message -f red
          exit
        }

        # support hashtable or string as response
        if ($_block_result -is "hashtable") {
          _write -res $_res -hash $_block_result
        }
        else {
          _write_text -res $_res -text $_block_result
        }
      }
      else {
        # no matched router
        _write -res $_res `
               -hash @{code = 404; body = "<h1>404 Not Found</h1><h2>$key</h2>"}
      }

      _log_once
    }
    catch {
      continue
    }
  }

  $server.stop()
  "Sinatra stopped his performance"
  exit
}

function _log_once {
  $ip = $_req.RemoteEndPoint
  $time = get-date
  $method = $_req.HttpMethod
  $path = $_req.RawUrl
  $ver = $_req.ProtocolVersion
  $code = $_res.StatusCode
  "$ip -- [$time] `"$method $path`" HTTP $ver $code"
}

