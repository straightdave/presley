$key = "GET /name/:name/age/:age"
$_param = @{}

# routers to test
$req_key = "GET /name/dave/age/123"

# begin test process
$key_pattern = $key -replace ":(\w+)", "(?<$+>\w+)"

if ($req_key -match $key_pattern) {
  $matches.keys | % {
    if ($_ -is "string") {
      $_param[$_] = $matches[$_]
    }
  }

  "matched"
  $_param
}
else {
  "not match"
}