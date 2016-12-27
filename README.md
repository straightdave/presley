# pSinatra
[sinatra](http://www.sinatrarb.com/) for PowerShell!

Don't you think it is extremely hard to setup a simple HTTP server on Windows? Have you ever tried a lot to install a Visual Studio, or downloading huge .Net framework, or doing a great deal of boilerplate work with ASP.NET just for a small and simple server?
Installing DevKit to mimic things on Linux platform, like Rails (ruby) or Flask (python)? It works but you know on Windows...

OK. This one is for you.

## How to use

Create a PowerShell script file, then:

1. Load pSinatra library
```powershell
. .\psinatra.ps1    # I really love this way loading
```

2. Define your routers
```powershell
get '/' {
	# do something for 'GET / HTTP 1.1'

	"Hello world!"  # => last string as http body
}

get '/hello' {
	# do something for 'GET /hello HTTP 1.1'

	$name = $_param["name"]
	"Hello $name!"  # => last string as http body
}

get '/weirdheader' {
	
	@{ code = 404; headers = @{ my_header = "header1" }, body = "<h1>hello</h1>"}
}
```

3. Add a run command (literally)
```powershell
run
```

Full script:
```powershell
. .\psinatra.ps1

get '/' {
	# do something for 'GET / HTTP 1.1'

	"Hello world!"  # => last string as http body
}

get '/hello' {
	# do something for 'GET /hello HTTP 1.1'

	$name = $_param["name"]
	"Hello $name!"  # => last string as http body
}

get '/weirdheader' {
	
	@{ code = 404; headers = @{ my_header = "header1" }, body = "<h1>hello</h1>"}
}

run
```

## Run! Run!
After definding your routers in `app.ps1`, invoke the script:

```
PS> .\app.ps1
```
