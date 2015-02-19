debug = require("debug")("cachify")
redis = require "redis"
LRU = require "lru-cache"
{EventEmitter} = require "events"
_ = require "underscore"

parse = (str) ->
  try
    JSON.parse(str)
  catch e
    {}


class LocalCache

  constructor: ->
    @data = {}

  set: (id, result, expiry) ->
    if @data[id]
      clearTimeout @data[id].timer
    timer = setTimeout =>
      @data[id] = null
    , (expiry - Date.now())
    @data[id] = {result, expiry, timer}
    result

  get: (id) ->
    result = @data[id]
    if result and (result.expiry > Date.now())
      result.result



class Cachify

  defaults:
    defaultExpiry: 60
    cacheInProcess:false
    redisChannel: "cache"

  constructor: (opts) ->
    _.extend @, @defaults, opts

    # Need an in memory cache to stop duplicate calls to a function
    @localCache = LRU
      maxAge: 10 * 1000
      max: 1000

    # We use a local event emitter instance for event binding / unbinding
    @bridge = new EventEmitter
    # Quite conceivable that a user may have 10+ accounts,
    @bridge.setMaxListeners(100)

    @redisPubsub.on "message", (channel, message) =>
      debug "pubsub: #{message}"
      @bridge.emit message
    @redisPubsub.subscribe(@redisChannel)



  make: (idFn, expiry, fn) =>
    if not fn
      fn = expiry
      expiry = @defaultExpiry
    store = @redisStore
    pubsub = @redisPubsub
    bridge = @bridge
    localCache = @localCache
    if @cacheInProcess
      resultCache = new LocalCache
    expiryMs = expiry * 1000
    redisChannel = @redisChannel



    # The wrapped function to return
    (data, callback) ->
      throw new Error("Data & callback expected only one supplied") unless callback

      # If the id is provided as a function, then retrive the id from the data
      if _.isFunction(idFn)
        id = idFn(data)
      else
        id = idFn


      callback = _.once callback # safety check to ensure that callback is only called once

      # The listener function to be added to the bridge
      listener = ->
        debug "listener called for:" + id
        store.get id, (err, result) ->
          result = parse(result)
          if result?.status is "pending"
            err = "Pending"
          else if result?.status is "error"
            err = result?.err or "Error"
          else if result?.status is "success"
            if resultCache then resultCache.set id, result.result, result.expires
            result = result.result

          callback(err, result)

      get = ->
        debug "get called for:" + id
        fn data, (err, result) ->
          debug "get callback for:" + id
          localCache.del(id)
          if err
            debug "err in callback for:" + id
            toSave = {status:"error", err}
          else
            toSave = {status: "success", result, expires: Date.now() + expiryMs}
            debug "setting result for" + id
          if resultCache then resultCache.set id, result, Date.now() + expiryMs
          store.set id, JSON.stringify(toSave), 'ex', expiry, (err2) ->
            store.publish(redisChannel, id)
            callback(err ? err2, result)

      if resultCache
        debug "checking memory cache"
        result = resultCache.get(id)
        if result
          debug "memory cache hit"
          return callback(null, result)


      debug "checking store"
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
        debug "status: #{status}"



        switch status
          when "miss", "error"
            debug "cache miss"
            localCache.set(id, true)
            store.set id, JSON.stringify({status:"pending"}), "ex", 10, -> # 10 second expiry in case the call fails
            get()

          when "pending"
            debug "cache pending: #{id} - #{result}"
            bridge.once id, listener
            # Set up a timeout, in case the pubsub event is never called
            setTimeout ->
              bridge.removeListener(id, listener)
              get()
            , (10 * 1000)

          when "success"
            debug "cache hit: #{id}"
            callback err, result.result





module.exports = (options = 60, depreceatedRedisPort = 6379, depreceatedRedisHost = "localhost") ->
  # To support deprecated init options
  if _.isNumber(options)
    options =
      defaultExpiry: options
    if _.isNumber(depreceatedRedisPort)
      options.redisPort = depreceatedRedisPort
      options.redisHot = depreceatedRedisHost
    else
      options.redisPubsub = depreceatedRedisPort
      options.redisStore = depreceatedRedisHost

  unless options.redisPubsub and options.redisStore
    options.redisPubsub = redis.createClient(options.redisPort, options.redisHost)
    options.redisStore = redis.createClient(options.redisPort, options.redisHost)

  cachify = new Cachify options
  cachify.make
