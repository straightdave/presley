#=====================================================
# psinatra.ps1 
# - http://github.com/straightdave/psinatra
#
# Naming rules:
# - all pre-defined objects that exposed 
#   to programmers have prefix "_";
# - all pre-defined functions that exposed 
#   to programmers have no prefix "_";
#=====================================================

$global:_req    = $null
$global:_params = $null
$global:_res    = $null
$global:_body   = $null
$global:_path_variables = @{}

$routers = @{}
$router_patterns = @{}

function get($path, $block) {
  $routers["GET $path"] = $block
}

function post($path, $block) {
  $routers["POST $path"] = $block
}

function run($bind = "localhost", [int]$port = 9999) {
  [console]::TreatControlCAsInput = $true

  if (-not [system.net.httplistener]::IsSupported) {
    write-host "http listener is not supported" -f red
    exit
  }

  # pre-process: analyze their matching patterns
  $routers.keys | % {
    $p = $_ -replace ":(\w+)", "(?<$+>\w+)"
    $router_patterns["^$p$"] = $routers[$_]
  }

  # start server
  $address = "http://$($bind):$($port)"
  try {
    $server = new-object -type system.net.httplistener
    $server.prefixes.add("$address/")
    $server.start()
    write-host "Sinatra is started at $address" -f cyan
  }
  catch {
    write-host "cannot start listening at $address" -f red
    exit
  }

  while($server.IsListening) {
    if ([console]::KeyAvailable) {
      $key = [system.console]::readkey($true)
      if (($key.modifiers -band [consolemodifiers]"control") `
          -and ($key.key -eq "C"))
      {  
        write-host "Sinatra is leaving the stage..." -f yellow
        break
      }
    }

    # block until get new request
    $context        = $server.GetContext()

    # (re)set variables per each request
    $start_time     = Get-Date
    $global:_req    = $context.Request
    $global:_res    = $context.Response
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

        # set request body and add POST/PUT params
        if ($_req.HttpMethod -eq "POST" -or `
            $_req.HttpMethod -eq "PUT") {
          $reader = new-object -type system.io.streamreader `
                    $_req.inputstream
          $global:_body = $reader.readtoend()
          $global:_body.split('&') | % {
            $this_kv = $_
            $splits = $this_kv.split('=')
            $global:_params[$($splits[0])] = (?? $splits[1] "")
          }
        }

        # execute block and respond
        $block_result = $block.Invoke($global:_path_variables)[-1]
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
               -hash @{code = 404; body = "<h1>Sinatra doesn't know this ditty</h1><h2>$key</h2>"}
      }

      _log_once -start $start_time
    }
    catch {
      write-host $_.exception.message -f red
      # break
    }
  }

  $server.stop()
  "Sinatra stopped his performance. [Applaud]"
  exit
}

function _log_once($start) {
  $time   = $start
  $dur    = (Get-Date).millisecond - $start.millisecond
  $ip     = $_req.RemoteEndPoint
  $method = $_req.HttpMethod
  $path   = $_req.RawUrl
  $ver    = $_req.ProtocolVersion
  $code   = $_res.StatusCode
  "$ip -- [$time] `"$method $path`" HTTP $ver $code ($dur ms)"
}

function _matching_router($request_to_test) {
  $block = $null
  $router_patterns.keys | % {
    $this_p = $_
    if ($request_to_test -match $this_p) {
      $matches.keys | % {
        if ($_ -is "string") {
          $global:_params[$_]         = $matches[$_]
          $global:_path_variables[$_] = $matches[$_]
        }
      }
      $block = $router_patterns[$this_p]
      return
    }
  }
  $block
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

