###
  Basic cache pub / sub system.
###


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


module.exports = (expiry = 60, redisPort = 6379, redisHost = "localhost") ->

  pubsub = redis.createClient(redisPort, redisHost)
  store = redis.createClient(redisPort, redisHost)


  # Set redis pubsub messages to be emitted by the local event emitter
  pubsub.on "message", (channel, message) ->
    bridge.emit message
  pubsub.subscribe("cache")

  # The wrapping function, takes an id (string or function), and a function that has 2 arguments: data, callback
  (idFn, fn) ->

    # The wrapped function to return
    (data, callback) ->

      # If the id is provided as a function, then retrive the id from the data
      if _.isFunction(idFn)
        id = idFn(data)
      else
        id = idFn


      #callback = _.once callback # safety check to ensure that callback is only called once

      # The listener function to be added to the bridge
      listener = ->
        #console.log "listener called for:" + id
        store.get id, (err, result) ->
          result = parse(result)
          if result?.status is "pending"
            err = "Pending"
          else if result?.status is "error"
            err = result?.err or "Error"
          callback(err, result)

      get = ->
        #console.log "get called for:" + id
        fn data, (err, result) ->
          #console.log "get callback for:" + id
          localCache.del(id)
          if err
            console.log "err in callback for:" + id
            store.set id, JSON.stringify({status:"error", err})
          else
            result.status = "success"
            #console.log "setting result for" + id
            store.set id, JSON.stringify(result), (err) ->
              store.publish("cache", id)
              store.expire id, expiry

          callback(err, result)



      store.get id, (err, result) ->
        # Get the result from the redis store
        # Three outcomes, exists, pending, doesn't exist

        if result
          result = parse(result)
          unless result.status is "pending"
            # Case for retrieved data
            #console.log "cache hit", id
            if result.status is "error" then err = result.err
          return callback err, result

        else
          # Case for no data or an error
          unless localCache.get(id)
            console.log "cache miss", id
            localCache.set(id, true)
            store.set id, JSON.stringify({status:"pending"}), ->
              store.expire id, 10 # 10 second expiry in case the call fails
          return get()

        # Case for pending data
        # Set up a listener on the bridge that will be called on a redis pubsub
        #console.log "cache pending", id, result
        bridge.once id, listener
        # Set up a timeout, in case the pubsub event is never called
        setTimeout ->
          bridge.removeListener(id, listener)
          get()
        , (10 * 1000)
