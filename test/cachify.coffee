{ok, equal, notEqual} = require("assert")
_ = require "underscore"
rand = -> Date.now() + Math.random()

cachify = require('../index')({cacheInProcess:true})

describe 'cachify', ->
  it 'works with defaults', (done) ->

    fn = (data, callback) ->
      setTimeout ->
        callback(null, "yes")
      , 500

    id = rand()

    cachified = cachify(id, 60, fn)

    cachified {}, (err, result) ->
      equal result, "yes"
      done(err)

  it 'works with errors sync', (done) ->
    # When multiple synchronous calls are made to a cachified function
    # Any errors should be propogated to all the calls
    called = false

    fn = (data, callback) ->
      setTimeout ->
        if called
          callback(null, "yes")
        else
          called = true
          callback("error")
      , 100

    id = rand()

    cachified = cachify(id, 60, fn)

    cachified {}, (err) ->
      equal err, "error"

    cachified {}, (err2) ->
      equal err2, "error"
      done()


  it 'works with errors async', (done) ->
    # cachified functions that result in an error shouldn't persist
    called = false

    fn = (data, callback) ->
      setTimeout ->
        if called
          callback(null, "yes")
        else
          called = true
          callback("error")
      , 500

    id = rand()

    cachified = cachify(id, 60, fn)

    cachified {}, (err, result) ->
      equal err, "error"

      cachified {}, (err2, result2) ->
        ok not err2, "Error shouldn't exist on second call"
        equal result2, "yes"
        done(err2)



  it 'works with multiple calls', (done) ->
    id = 0

    fn = (data, callback) ->
      setTimeout ->
        id += 1
        if id > 1 then throw new Error("called too many times")
        callback(null, id)
      , 500

    cachified = cachify(rand(), 60, fn)

    cachified {}, (err, result) ->
      equal result, 1

    cachified {}, (err, result) ->
      equal result, 1
      done(err)

  it 'works with multiple async calls', (done) ->
    id = 0

    fn = (data, callback) ->
      setTimeout ->
        id += 1
        if id > 1 then throw new Error("called too many times")
        callback(null, id)
      , 500

    cachified = cachify(rand(), 60, fn)

    setTimeout ->
      cachified {}, (err, result) ->
        equal result, 1
    , 50

    setTimeout ->
      cachified {}, (err, result) ->
        equal result, 1
    , 10

    setTimeout ->
      cachified {}, (err, result) ->
        equal result, 1
        done(err)
    , 1000



  it 'works with multiple synchronous calls only call fn once', (done) ->
    called = false

    fn = (data, callback) ->
      if called
        throw new Error("called more than once")
      called = true
      setTimeout ->
        callback(null, "yes")
      , 500

    fn = _.once(fn)

    id = rand()

    cachified = cachify(id, 60, fn)

    cachified {}, (err, result) ->
      equal result, "yes"

    cachified {}, (err, result) ->
      equal result, "yes"
      done(err)

  it 'works with dynamic id', (done) ->

    fn = (data, callback) ->
      setTimeout ->
        callback(null, data.id)
      , 500

    idFn = (data) -> data.id

    cachified = cachify(idFn, 60, fn)

    cachified {id:11}, (err, result) ->
      equal result, 11

    cachified {id:21}, (err, result) ->
      equal result, 21
      done(err)

  it 'expires correctly', (done) ->
    firstResult = null

    fn = (data, callback) ->
      setTimeout ->
        callback(null, Date.now())
      , 100

    cachified = cachify("expiry", 1, fn)

    cachified {}, (err, result) ->
      firstResult = result

      cachified {}, (err, result) ->
        equal result, firstResult

        setTimeout ->
          cachified {}, (err, result) ->
            notEqual result, firstResult
            done()
        , 2000


  it 'expires correctly with delay passed in at init', (done) ->
    firstResult = null

    fn = (data, callback) ->
      setTimeout ->
        callback(null, Date.now())
      , 100

    cachified = cachify("expiry-init", 1, fn)

    cachified {}, (err, result) ->
      firstResult = result

      cachified {}, (err, result) ->
        equal result, firstResult

        setTimeout ->
          cachified {}, (err, result) ->
            notEqual result, firstResult
            done()
        , 2000




