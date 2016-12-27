# load psinatra
. .\psinatra.ps1

# define routers (and actions)
get '/hello' {
  $name = $_param["name"]
  $path = $_req.Url.absolutepath

  # the last return item is a string
  "Hello $name at $path!"
}

get '/hi' {
  $response = @{}
  $response["code"] = 233
  $response["headers"] = @{ myheader = "wahahaa"; h33 = "2333333"}
  $response["body"] = "wahahaha hahaha"

  # the last return item is a hashtable
  $response
}

# run the application
run