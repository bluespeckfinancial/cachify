###
  Basic cache pub / sub system.

When function called, get the id
Check if id exists in the database





###
debug = false

log = -> if debug then console.log.apply(console, arguments)

parse = (str) ->
  try
    JSON.parse(str)
  catch e
    {}

redis = require "redis"
LRU = require "lru-cache"
{EventEmitter} = require "events"
_ = require "underscore"

# Need an in memory cache to stop duplicate calls to a function
localCache = LRU
  maxAge: 10 * 1000
  max: 1000

# We use a local event emitter instance for event binding / unbinding
bridge = new EventEmitter
# Quite conceivable that a user may have 10+ accounts,
bridge.setMaxListeners(100)

pubsub = null
store = null


module.exports = (expiryMain = 60, redisPort = 6379, redisHost = "localhost") ->
  unless pubsub
    pubsub = redis.createClient(redisPort, redisHost)
    store = redis.createClient(redisPort, redisHost)
    # Set redis pubsub messages to be emitted by the local event emitter
    pubsub.on "message", (channel, message) ->
      log "pubsub", message
      bridge.emit message
    pubsub.subscribe("cache")

  # The wrapping function, takes an id (string or function), and a function that has 2 arguments: data, callback
  (idFn, expiry, fn) ->
    if not fn
      fn = expiry
      expiry = expiryMain


    # The wrapped function to return
    (data, callback) ->

      # If the id is provided as a function, then retrive the id from the data
      if _.isFunction(idFn)
        id = idFn(data)
      else
        id = idFn


      callback = _.once callback # safety check to ensure that callback is only called once

      # The listener function to be added to the bridge
      listener = ->
        log "listener called for:" + id
        store.get id, (err, result) ->
          result = parse(result)
          if result?.status is "pending"
            err = "Pending"
          else if result?.status is "error"
            err = result?.err or "Error"
          else if result?.status is "success"
            result = result.result
          callback(err, result)

      get = ->
        log "get called for:" + id
        fn data, (err, result) ->
          log "get callback for:" + id
          localCache.del(id)
          if err
            log "err in callback for:" + id
            toSave = {status:"error", err}
          else
            toSave = {status: "success", result}
            log "setting result for" + id
          store.set id, JSON.stringify(toSave), (err2) ->
            store.publish("cache", id)
            store.expire id, expiry
            callback(err ? err2, result)


      log "checking store"
      store.get id, (err, result) ->
        # Get the result from the redis store
        # Three outcomes, exists, pending, doesn't exist
        return callback(err) if err
        if result
          result = parse(result)
          status = result.status
        else if localCache.get(id)
          status = "pending"

        status ?= "miss"
        log status, "status"




        switch status
          when "miss", "error"
            log "cache miss"
            localCache.set(id, true)
            store.set id, JSON.stringify({status:"pending"}), ->
              store.expire id, 10 # 10 second expiry in case the call fails
            get()

          when "pending"
            log "cache pending", id, result
            bridge.once id, listener
            # Set up a timeout, in case the pubsub event is never called
            setTimeout ->
              bridge.removeListener(id, listener)
              get()
            , (10 * 1000)

          when "success"
            log "cache hit", id
            callback err, result.result

