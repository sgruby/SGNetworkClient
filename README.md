# SGNetworkClient

This is a work in progress of a basic networking class to meet the needs
of many of my projects. It isn't overly complex, but handles many aspects
of iOS and Mac networking including retries, uploading of data, parsing of results, etc.

All of the responses come back on the main thread by default so there is no need to use
DispatchQueue.main in the responses. While there are cases to have the calls come back on
a separate queue, this simplifies a lot of things.

Comments and suggestions are welcome.

This requires Xcode 13.2 as it has support for async/await concurrency.