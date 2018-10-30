require 'sinatra/base'
require 'docker-api'
require 'concurrent'
require 'net/http'
require_relative 'docker_launch'

# This microservice provides an http interface to the docker service.
# It provides a REST API interface for:
#  - importing image
#  - exporting image
#  - list images
#  - delete image
#  - run task

class LibrouteWorker < Sinatra::Base

  # Import a provided image
  post '/import' do
    log = ''
    images = []
    imageIDs = []
    im = Docker::Image.load(request.body) do |v|
      begin
	v.each_line do |vv|
	  jj = JSON.parse(vv)
	  if jj.has_key?('stream')
            jjj = jj['stream'].split("\n")
	    jjj.each do |j|
	      images.push(j[14..-1]) if j[0..12].eql?('Loaded image:')
	      imageIDs.push(j[17..-1]) if j[0..15].eql?('Loaded image ID:')
	    end
	  end
	end
      end
    end
    return {"Images":images,"ImageIDs":imageIDs}.to_json
  end

  # Save an existing image
  get '/export/:image' do
    stream do |s|
      Docker::Image.save_stream(params['image']) do |chk|
        s << chk
      end
    end
  end

  # Get list of installed images
  get '/listimages' do
    images = []
    Docker::Image.all(all: true).each do |im|
      images.push(im.id)
    end
    images.to_json
  end

  # Delete an image
  delete '/image/:name' do
    im = Docker::Image.all(all: true).select{|im| im.id.eql?(params['name'])}.first
    if im.nil?
      halt 400, 'Error: Image not found'
    end
    im.delete(noprune: true)
    return "success"
  end

  # Run task
  post '/image/:name' do
    im = Docker::Image.all(all: true).select{|im| im.id.eql?(params['name'])}.first
    if im.nil?
      halt 400, 'Error: Image not found'
    end
    json_cmd = Base64.decode64(params['cmd'])
    stream do |s|
      DockerLaunch.run(im.id, s, {cmd: json_cmd}, request.body)
    end
  end

  # Build image
  post '/build/:name' do
    dockerfile = request.body.read
    im = Docker::Image.build(dockerfile)
    return Docker::Image.get(im.id).id
  end
end
