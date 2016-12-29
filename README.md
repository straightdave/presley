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

>Currently I've just implemented several matching patterns of GET request:
- GET /static_route
- GET /path/:with/some/:variable
- GET /path?with=querystrings

>For more info please refer to the `.\examples\example.ps1`

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

run
```

>for more detailed info, please refer to `.\examples\example.ps1`

## Run! Run!
After definding your routers in script `app.ps1`, execute this script:

```
PS> .\app.ps1
```

>you can stop listening loop by hitting 'Ctrl-C' in PowerShell session.
But currently you have to wait for the next request catch to stop the listening loop.
It will get improved (hopefully) in the short future.