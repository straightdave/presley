$defined_routers = @(
  "GET /name/:name/age/:age",
  "GET /hello"
)

$routers_to_test = @(
  "GET /name/dave/age/123/",
  "GET /name/dave/age/abc/ask",
  "GET /name/dave/age/123",
  "GET /hello/dave",
  "GET /hello",
  "GET /hello/",  # currently trailing '/' matters!
  "GET /"
)

function matching_router($patterns, $router_to_test) {
  $_param = @{}

  $patterns | % {
    $this_pattern = $_
    if ($router_to_test -match $this_pattern) {
      $matches.keys | % {
        if ($_ -is "string") {
          $_param[$_] = $matches[$_]
        }
      }

      "matched: $this_pattern"
      $_param
      return
    }
  }
}

# pre-processing
$router_patterns = @()
$defined_routers | % {
  $p = $_ -replace ":(\w+)", "(?<$+>\w+)"
  $router_patterns += "^$p$"
}

# matching each router-to-test
$routers_to_test | % {
  write-host "testing $_" -f cyan
  matching_router $router_patterns $_
  write-host
}
