assert = require("assert")
should = require("should")
http = require("request")
redis = require("redis")
util = require("util")
crypto = require 'crypto'
dcrypt = require 'dcrypt'
fs = require("fs")
rc = redis.createClient()
port = 443
baseUri = "https://localhost:" + port

cleanup = (done) ->
  keys = [
    "users:test",
    "users:test1",
    "users:notafriend",
    "friends:test",
    "friends:test1",
    "invites:test",
    "invited:test",
    "invites:test1",
    "invited:test1",
    "test:test1:id",
    "messages:test:test1",
    "conversations:test1",
    "conversations:test",
    "conversations:notafriend"]
  rc.del keys,(err, data) ->
    if err
      done err
    else
      done()

login = (username, password, done,  callback) ->
  http.post
    url: baseUri + "/login"
    json:
      username: username
      password: password
  , (err, res, body) ->
    if err
      done err
    else
      callback res, body

signup = (username, password, dhPub, dsaPub, authSig, done,  callback) ->
  http.post
    url: baseUri + "/users"
    json:
      username: username
      password: password
      dhPub: dhPub
      dsaPub: dsaPub
      authSig: authSig
  , (err, res, body) ->
    if err
      done err
    else
      callback res, body


describe "surespot server", () ->

  before (done) -> cleanup done

  describe "create user", () ->
    it "should respond with 201", (done) ->
      ecdsa = new dcrypt.keypair.newECDSA 'secp521r1'
      #ecdsa = new dcrypt.keypair.newECDH 'secp521r1'

      random = crypto.randomBytes 16

      dsaPubSig =
        crypto
          .createSign('sha256')
          .update(new Buffer("test"))
          .update(new Buffer("test"))
          .update(random)
          .sign(ecdsa.pem_priv, 'base64')

      sig = Buffer.concat [random, dsaPubSig]

      signup "test","test", ecdsa. sig.toString('base64'), done, (res, body) ->
        res.statusCode.should.equal 201
        done()

    it "and subsequently exist", (done) ->
      http.get
        url: baseUri + "/users/test/exists",
        (err,res,body) ->
          if err
            done err
          else
            body.should.equal "true"
            done()

#    it "even if the request case is different", (done) ->
#      http.get
#        url: baseUri + "/users/TEST/exists",
#        (err,res,body) ->
#          if err
#            done err
#          else
#            body.should.equal "true"
#            done()

    it "shouldn't be allowed to be created again", (done) ->
      signup "test","test", done, (res, body) ->
        res.statusCode.should.equal 409
        done()

    it "even if the request case is different", (done) ->
      signup "tEsT","test", done, (res, body) ->

        res.statusCode.should.equal 409
        done()

  describe "login with invalid credentials", ->
    it "should return 401", (done) ->
      login "test", "bollocks", done, (res, body) ->
        res.statusCode.should.equal 401
        done()

  describe "login with non existant user", ->
    it "should return 401", (done) ->
      login "your", "mama", done, (res, body) ->
        res.statusCode.should.equal 401
        done()


  describe "login with valid credentials", ->
    it "should return 204", (done) ->
      login "test","test",done,(res,body) ->
        res.statusCode.should.equal 204
        done()

  describe "invite exchange", ->
    it "created user", (done) ->
      signup "test1","test1", done, (res, body) ->
        res.statusCode.should.equal 201
        done()

    it "should not be allowed to invite himself", (done) ->
      http.post
        url: baseUri + "/invite/test1", (err, res, body) =>
          if err
            done err
          else
            res.statusCode.should.equal 403
            done()


    it "who invites a user successfully should receive 204", (done) ->
      http.post
        url: baseUri + "/invite/test", (err, res, body) =>
          if err
            done err
          else
            res.statusCode.should.equal 204
            done()

    it "who invites them again should receive 403", (done) ->
      http.post
        url: baseUri + "/invite/test", (err, res, body) =>
          if err
            done err
          else
            res.statusCode.should.equal 403
            done()

    it "who accepts their invite should receive 204", (done) ->
      login "test","test",done,(res, body) ->
        http.post
          url: baseUri + "/invites/test1/accept", (err, res, body) ->
            if err
              done err
            else
              res.statusCode.should.equal 204
              done()

    it "who accepts a non existent invite should receive 404", (done) ->
      http.post
        url: baseUri + "/invites/nosuchinvite/accept", (err, res, body) ->
          if err
            done err
          else
            res.statusCode.should.equal 404
            done()


    it "who invites them again should receive a 409", (done) ->
      http.post
        url: baseUri + "/invite/test1", (err, res, body) =>
          if err
            done err
          else
            res.statusCode.should.equal 409
            done()


  describe "inviting non existent user", ->
    it "should return 404", (done) ->
      http.post
        url: baseUri + "/invites/nosuchuser", (err, res, body) ->
          if err
            done err
          else
            res.statusCode.should.equal 404
            done()


  describe "getting the public key of a non existant user", ->
    it "should return not found", (done) ->
      http.get
        url: baseUri + "/publickey/nosuchuser", (err, res, body) ->
          if err
            done err
          else
            res.statusCode.should.equal 404
            done()

  describe "getting the public key of a non friend user", ->
    it "should not be allowed", (done) ->
      signup "notafriend", "notafriend", done, (res, body) ->
        http.get
          url: baseUri + "/publickey/test", (err, res, body) ->
            if err
              done err
            else
              res.statusCode.should.equal 403
              done()

  describe "getting other user's last 30 messages", ->
    it "should not be allowed", (done) ->
      http.get
        url: baseUri + "/messages/test", (err, res, body) ->
          if err
            done err
          else
            res.statusCode.should.equal 403
            done()
  describe "getting other user's messages after x", ->
    it "should not be allowed", (done) ->
      http.get
        url: baseUri + "/messages/test/after/0", (err, res, body) ->
          if err
            done err
          else
            res.statusCode.should.equal 403
            done()
  describe "getting other user's messages before x", ->
    it "should not be allowed", (done) ->
      http.get
        url: baseUri + "/messages/test/before/100", (err, res, body) ->
          if err
            done err
          else
            res.statusCode.should.equal 403
            done()

  describe "uploading an image to a valid spot", ->
    location = undefined
    it "should return the location header and 202", (done) ->
      login "test", "test", done, (res, body) ->
        r = http.post baseUri + "/images/test1", (err, res, body) ->
          if err
            done err
          else
            res.statusCode.should.equal 202
            location = res.headers["location"]
            should.exists location
            done()

        form = r.form()
        form.append "image", fs.createReadStream "test"
        #todo set filename explicitly

    it "should return the same image when location url requested", (done) ->
      http.get
        url: baseUri + location, (err, res, body) ->
          if err
            done err
          else
            res.statusCode.should.equal 200
            res.body.should.equal "madman\n"
            done()

  describe "getting images from non existent spots", ->
    it "should return 404", (done) ->
      http.get
        url: baseUri + "/images/test:test1/6000", (err, res, body) ->
          if err
            done err
          else
            res.statusCode.should.equal 404
            done()

  describe "getting images from spots we don't belong to", ->
    it "should not be allowed", (done) ->
      http.get
        url: baseUri + "/images/a:room/1", (err, res, body) ->
          if err
            done err
          else
            res.statusCode.should.equal 403
            done()

  describe "uploading an image to a spot we don't belong to", ->
    it "should not be allowed", (done) ->
      login "notafriend", "notafriend", done, (res, body) ->
        r = http.post baseUri + "/images/test1", (err, res, body) ->
          if err
            done err
          else
            res.statusCode.should.equal 403
            done()

        form = r.form()
        form.append "image", fs.createReadStream "test"
  #todo set filename explicitly
  after (done) -> cleanup done