
function New-ScriptBlockCallback {
    # thank you Oisin G.
    # http://www.nivot.org/blog/post/2009/10/09/PowerShell20AsynchronousCallbacksFromNET
    param(
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [scriptblock]$Callback
    )
    if (-not ("CallbackEventBridge" -as [type])) {
        Add-Type @"
            using System;
             
            public sealed class CallbackEventBridge
            {
                public event AsyncCallback CallbackComplete = delegate { };
 
                private CallbackEventBridge() {}
 
                private void CallbackInternal(IAsyncResult result)
                {
                    CallbackComplete(result);
                }
 
                public AsyncCallback Callback
                {
                    get { return new AsyncCallback(CallbackInternal); }
                }
 
                public static CallbackEventBridge Create()
                {
                    return new CallbackEventBridge();
                }
            }
"@
    }
    $bridge = [callbackeventbridge]::create()
    Register-ObjectEvent -input $bridge -EventName callbackcomplete -action $callback -messagedata $args > $null
    $bridge.callback
}