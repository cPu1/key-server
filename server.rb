require 'sinatra'
require 'json'
require_relative 'key_gen'

set :show_exceptions, :after_handler

helpers do
  def json(o)
    JSON.generate(o)
  end
end

key_gen = KeyGen.new

post '/keys' do
  key_gen.generate
  201
end

get '/keys' do
  key = key_gen.block()
  if key
    json({key: key})
  else
    404
  end
end

post '/keys/:key/unblock' do
  key_gen.unblock(params['key'])
  200
end

delete '/keys/:key' do
  key_gen.delete(params['key'])
  200
end

post '/keys/:key/refresh' do
  key_gen.refresh_key(params['key'])
  200
end

get '/keys/inspect' do
  key_gen.inspect
end

error KeyGenError do
  [404, (env['sinatra.error'].message)]
end
