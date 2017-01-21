. ..\psinatra.ps1

get '/hello/:name' {
  $name = $_params["name"]
  eps 'hello' @{ name = $name }
}

run