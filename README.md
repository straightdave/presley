# pSinatra
[sinatra](http://www.sinatrarb.com/) for PowerShell!

Don't you think it is extremely hard to setup a simple HTTP server on Windows? Have you ever tried a lot to install a Visual Studio, or downloading huge .Net framework, or doing a great deal of boilerplate work with ASP.NET just for a small and simple server?
Installing DevKit to mimic things on Linux platform, like Rails (ruby) or Flask (python)? It works but you know on Windows...

OK. This one is for you.

## How to use

Create a PowerShell script file, then:

* Load pSinatra library

```powershell
. .\psinatra.ps1    # I really love this way loading
```

* Define your routers

>Currently I've just implemented several matching patterns of GET/POST request:
- GET /static_route
- GET /path/:with/some/:variable
- GET /path?with=querystrings
- POST /people (with request body. Path patterns are also available for POST)
- ...

>For more info please refer to the scripts in `.\examples\`

```powershell
get '/' {
  "Hello world!"
}

get '/hello' {
  $name = $_params["name"]
  "Hello $name!"
}

get '/someurl' {
  # respond with status code, your extra headers or body
  @{ code = 404; headers = @{ my_header = "header1" }; body = "<h1>hello</h1>"}
}

get '/aloha/:name/age/:age' {
  $name = $_params["name"]
  $age  = $_params["age"]

  "Aloha $name, you are $age!"
}

post '/people' {
	$name = $_params["name"]  # you can get post params quickly this way

	# in POST/PUT request handlers, you can get raw body content
	# by $_body
	"posted data: name = $name, body = $_body"
}
```

* Add a run command (literally)

```powershell
run
```

The full script is like:

```powershell
. .\psinatra.ps1

get '/' {
  "Hello world!"
}

get '/hello' {
  $name = $_params["name"]
  "Hello $name!"
}

get '/weirdheader' {
  @{ code = 404; headers = @{ my_header = "header1" }; body = "<h1>hello</h1>"}
}

post '/people' {
	# add a person data
	"{`"msg`": `"done`"}"
}

run
```

## Run! Forrest, Run!
After definding your routers in script `app.ps1`, execute this script:

```
PS> .\app.ps1
```
Then a web service listener is started at http://localhost:9999 by default.
You can provide specific binding or port to `run` function like:
```powershell
run -bind '127.0.0.1' -port 4567
```

>you can stop listening loop by hitting 'Ctrl-C' in PowerShell session.
But currently you have to wait for the next request catch to stop the listening loop since http listening blocks.
It will get improved (hopefully) in the short future.
