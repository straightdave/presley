#==============
# psinatra.ps1
#==============

$_routers = @{}
$_router_patterns = @{}

$global:_req    = $null
$global:_params = $null
$global:_path_variables = @{}
$global:_res    = $null

function get($path, $block) {
  $_routers["GET $path"] = $block
}

function post($path, $block) {
  $_routers["POST $path"] = $block
}

function get_routers {
  $_routers
}

#=====================================================
# function 'run': the main process of app
# - bind address and port are changeable
# * Note: ensure this is called at the end, 
#         or some internal functions are invailable
#=====================================================
function run($bind = "localhost", [int]$port = 9999) {
  [console]::TreatControlCAsInput = $true

  if (-not [system.net.httplistener]::IsSupported) {
    write-host "http listener is not supported" -f red
    exit
  }

  # pre-process _routers for pattern matching
  $_routers.keys | % {
    $p = $_ -replace ":(\w+)", "(?<$+>\w+)"
    $_router_patterns["^$p$"] = $_routers[$_]
  }

  # start server
  $address = "http://$($bind):$($port)"
  try {
    $server = new-object -type system.net.httplistener
    $server.prefixes.add("$address/")
    $server.start()
    write-host "Sinatra is started on $address" -f cyan
  }
  catch {
    write-host "cannot start listening at $address" -f red
    exit
  }

  while($server.IsListening) {
    if ([console]::KeyAvailable) {
      $key = [system.console]::readkey($true)
      if (($key.modifiers -band [consolemodifiers]"control") -and ($key.key -eq "C"))
      {  
        write-host "Sinatra is leaving the stage..." -f yellow
        break
      }
    }

    $_context       = $server.GetContext() # blocking here
    $global:_req    = $_context.Request
    $global:_res    = $_context.Response
    $global:_params = $_req.QueryString
    $global:_path_variables = @{}

    try {
      $key   = $_req.HttpMethod + " " + $_req.Url.AbsolutePath
      $block = _matching_router $key
      if ($block -ne $null) {
        if ($block -isnot "scriptblock") {
          write-host "no block defined for $key" -f red
          break
        }

        # execute block
        $block_result = $block.Invoke($global:_path_variables)[-1]
        
        # respond
        if ($block_result -is "hashtable") {
          _write -res $_res -hash $block_result
        }
        else {
          _write_text -res $_res -text $block_result
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
      write-host $_.exception.message -f red
      break
    }
  }

  $server.stop()
  "Sinatra stopped his performance"
  exit
}

function _log_once {
  $time   = get-date
  $ip     = $_req.RemoteEndPoint
  $method = $_req.HttpMethod
  $path   = $_req.RawUrl
  $ver    = $_req.ProtocolVersion
  $code   = $_res.StatusCode
  "$ip -- [$time] `"$method $path`" HTTP $ver $code"
}

function _matching_router($router_to_test) {
  $_block = $null
  $_router_patterns.keys | % {
    $this_p = $_
    if ($router_to_test -match $this_p) {
      $matches.keys | % {
        if ($_ -is "string") {
          $global:_params[$_]         = $matches[$_]
          $global:_path_variables[$_] = $matches[$_]
        }
      }
      $_block = $_router_patterns[$this_p]
      return
    }
  }
  $_block
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

