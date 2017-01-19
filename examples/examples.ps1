# load psinatra
. ..\psinatra.ps1

get '/mul' {
  $name = $_params['name']
  $age = $_params['age']
  $hobby = $_params['hobby']

  "$name is $age, like $hobby"
}

# matching 'GET /hello' or 'GET /hello?name=dave' and so on
get '/hello' {
  # $_params is a pre-defined hashtable of query string per request
  # say, if matched '/hello?name=dave&age=12', then 
  # $_params['name'] => dave and $_params['age'] => 12
  $name = $_params["name"]

  # $_req is pre-defined HttpListenerRequest object per request
  # you can get more data about the request from it
  $path = $_req.Url.absolutepath

  # there're two ways to make http response
  # pure text way:
  #    the last string value of the block
  #    as the http body value (this example)
  "Hello $name at $path!"
}

# matching 'GET /hi'
get '/hi' {
  # there're two ways to make http response
  # the following is the basic way:
  #    the last hashtable value of the block
  #    in which you can provide 'code' as http status code,
  #    'headers' (another hashtable) as your extra http headers,
  #    'body' as http body
  $response = @{}
  $response["code"] = 233
  $response["headers"] = @{ myheader = "wahahaa"; h33 = "2333333"}
  $response["body"] = "wahahaha hahaha"

  # use the hashtable as response
  $response
}

# matching 'GET /getjson' and respond with a json
get '/getjson' {
  @{ 
    headers = @{'ContentType' = 'application/json'}
    body    = "{`"msg`":`"a msg`"}"
  }
}

# matching 'GET /hi/dave/age/123' and such alike
# but not 'GET /hi/dave/age/123/hahaha'
get '/hi/:name/age/:age' {
  # you can get path variables from both '_params' and '_path_variables'
  $name = $_path_variables["name"] 
  $age  = $_params["age"]

  "Hello $name is at age $age!"
}

# matching 'GET /hello/dave' and such alike
# in this example you get path variables from block param
get '/hello/:name' {
  param($var)   

  # you can get path variables from block param this way:
  "Hello $($var['name']) is at age $($var['age'])!"
}

# run the application
# you can specify bind or port
# like: run -bind '127.0.0.1' -port 4567
# default: run at 'localhost' on port 9999
run