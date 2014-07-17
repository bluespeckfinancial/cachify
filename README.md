Redis Cachify
=============

## Simple Redis & Memory Caching Library

### Install

`npm install redis-cachify --save`

### Usage

This library requires either existing redis connetions, or redis host and port settings.

e.g.

```coffeescript
Cachify = require("redis-cachify")
cachify = Cachify
  redisPort: 6379
  redisHost: "localhost"

# OR

cachify = Cachify
  redisStore: redisClient (in normal mode)
  redisPubsub: redisClient (in pubsub mode)

# Other options (with defaults are):

cachify = Cachify
  redisPort: 6379
  redisHost: "localhost"
  defaultExpiry: 60 # (time in seconds for functions to be cached)
  cacheInProcess: false # (turns on in-process cachcing, see details below)
  redisChannel: "cache" # (the Redis pubsub channel to use)
```

Once you have a cachify instance you can use it as follows:

`cachifiedFunction = cachify(id, myFunction)`

This library currently expects all functions that it is applied to, to have the following signature:

` myFunction = (data, callback) ->`

Callbacks are standard Node-style callbacks that are expected to receive an optional error and then a result.

`id` can be a string, e.g. - `"usd2gbp'` or a function, e.g. `(data) -> "userToken:" + data.userId`. If the `id` argument is a function, then it will be passed the data argument passed in each time the function is called.

A cachified version of a function can be used in excactly the same way as the function that was passed into it.
The difference being that the result will be cached in Redis and returned much sooner.

If you make a 10 calls to cachifiedFunction (with the same data), then myFunction will only be called once.

#### Custom Expiry per Function

Simply pass in the expity time in seconds as the second argument:

`cachifiedFunction = cachify(id, 120, myFunction)`

#### In Process Cache

If `inProcessCache` is set to `true` then the result of `myFunction` will be saved both in Redis and in a local memory
cache. This can improve performance by preventing unncecesary IO to Redis, but could result in slight race conditions -
so it is turned off by default. The race conditions would only occur at the time of a results expiry from
the cache. The in process cache could be slighly slower at expiring the data than Redis. This is highly unlikely to
cause a problem - but you should be aware of it.


### Troubleshooting

This library has a basic test suite and has been used extensively in production.
If you are having problems, try running your program with the environment variable DEBUG=cachify
This will print a whole load of debugging information to the console.


