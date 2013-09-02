{ok, equal, notEqual} = require("assert")
_ = require "underscore"
rand = -> Date.now() + Math.random()



describe 'cachify', ->
  it 'works with defaults', (done) ->
    cachify = require('../index')()

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
    cachify = require('../index')()
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
    cachify = require('../index')()
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
    cachify = require('../index')()

    fn = (data, callback) ->
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

  it 'works with multiple synchronous calls only call fn once', (done) ->
    cachify = require('../index')()
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
    cachify = require('../index')()

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
    cachify = require('../index')()
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
    cachify = require('../index')(1)
    firstResult = null

    fn = (data, callback) ->
      setTimeout ->
        callback(null, Date.now())
      , 100

    cachified = cachify("expiry-init", fn)

    cachified {}, (err, result) ->
      firstResult = result

      cachified {}, (err, result) ->
        equal result, firstResult

        setTimeout ->
          cachified {}, (err, result) ->
            notEqual result, firstResult
            done()
        , 2000


