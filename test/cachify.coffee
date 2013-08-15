{ok, equal, notEqual} = require("assert")
_ = require "underscore"


describe 'cachify', ->
  it 'works with defaults', (done) ->
    cachify = require('../index')()

    fn = (data, callback) ->
      setTimeout ->
        callback(null, "yes")
      , 500

    id = 1

    cachified = cachify(id, fn)

    cachified {}, (err, result) ->
      equal result, "yes"
      done(err)


  it 'works with multiple calls', (done) ->
    cachify = require('../index')()

    fn = (data, callback) ->
      setTimeout ->
        callback(null, "yes")
      , 500

    fn = _.once(fn)

    id = 1

    cachified = cachify(id, fn)

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

    id = 1

    cachified = cachify(id, fn)

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

    cachified = cachify(idFn, fn)

    cachified {id:11}, (err, result) ->
      equal result, 11

    cachified {id:21}, (err, result) ->
      equal result, 21
      done(err)

  it 'expires correctly', (done) ->
    cachify = require('../index')(1)
    firstResult = null

    fn = (data, callback) ->
      setTimeout ->
        callback(null, Date.now())
      , 100

    cachified = cachify("expiry", fn)

    cachified {}, (err, result) ->
      firstResult = result

      cachified {}, (err, result) ->
        equal result, firstResult

        setTimeout ->
          cachified {}, (err, result) ->
            notEqual result, firstResult
            done()
        , 1000


