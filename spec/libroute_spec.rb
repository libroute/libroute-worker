ENV['RACK_ENV'] = 'test'

require_relative '../libroute_worker.rb'
require_relative 'spec_helper.rb'
require 'rspec'
require 'rack/test'
require 'ostruct'

describe 'Libroute Worker' do
  include Rack::Test::Methods

  def app
    LibrouteWorker
  end

  it "full load, list, delete integration test", integration: true do
    # Clean environment - delete all images
    Docker::Container.all(all: true).each do |c|
      c.stop
      c.delete
    end
    Docker::Image.all.each{|im| im.delete(force: true)}

    # Load alpine image
    header 'Content-Type', 'application/octet-stream'
    post "/import", File.read('alpine_3.8.dockerimage')
    alpine_hash = "sha256:196d12cf6ab19273823e700516e98eb1910b03b17840f9d5509f03858484d321"
    expect(last_response.status).to be(200)

    # List should show one image
    get '/listimages'
    resp = last_response.body
    resp_json = JSON.parse(resp)
    expect(resp_json.length).to be(1)
    expect(resp_json[0]).to eq(alpine_hash)

    # Run should succeed
    data = 'abcdefg'
    cmd = ['ls','-lha']
    post "/image/#{alpine_hash}?cmd=#{Base64.encode64(cmd.to_json)}", data
    expect(last_response.body).to eq({Stream: 'stdout', Data: data.reverse}.to_json)

    # Build new image from existing
    post "/build/alpine_test", "FROM #{alpine_hash}\nRUN echo \"test\" > /datafile"
    alpine_new_hash = last_response.body

    # Run should succeed
    data = 'hijklmnop'
    cmd = ['rev']
    post "/image/#{alpine_hash}?cmd=#{Base64.encode64(cmd.to_json)}", data
    expect(last_response.body).to eq({Stream: 'stdout', Data: data.reverse}.to_json)

    # Delete should succeed
    delete "/image/#{alpine_new_hash}"
    expect(last_response.status).to eq(200)

    # Delete should succeed
    delete "/image/#{alpine_hash}"
    expect(last_response.status).to eq(200)

    # Delete again should fail
    delete "/image/#{alpine_hash}"
    expect(last_response.status).to eq(400)

    # List
    get '/listimages'
    resp = last_response.body
    resp_json = JSON.parse(resp)
    expect(resp_json.length).to be(0)
  end

  it "imports image" do
    stub_const("Docker::Image", double('docker-image'))
    expect(Docker::Image).to receive(:load) do |a,&blk|
      expect a.read().eql?("BINARY")
      blk.call('{"stream":"Loaded image: testimage"}')
      blk.call('{"stream":"Loaded image ID: abc"}')
      blk.call('{"stream":"Loaded image ID: def"}')
    end
    header 'Content-Type', 'application/octet-stream'
    post '/import', "BINARY"
    resp = last_response.body
    resp_json = JSON.parse(resp)
    expect(resp_json['Images'].length).to eq(1)
    expect(resp_json['ImageIDs'].length).to eq(2)
    expect(resp_json['Images'][0]).to eq('testimage')
    expect(resp_json['ImageIDs'][0]).to eq('abc')
    expect(resp_json['ImageIDs'][1]).to eq('def')
  end

  it "exports image" do
    stub_const("Docker::Image", double('docker-image'))
    expect(Docker::Image).to receive(:save_stream) do |&blk|
      blk.call("binary")
      blk.call("data")
    end
    get '/export/alpine:latest'
    resp = last_response.body
    expect(resp).to eq("binarydata")
  end

  it "lists images" do
    images = []    
    images.push(OpenStruct.new({id: 'sha256:abc123'}))
    images.push(OpenStruct.new({id: 'sha256:def456'}))
    stub_const("Docker::Image", double('docker-image'))
    expect(Docker::Image).to receive(:all).and_return(images)
    get '/listimages'
    resp = last_response.body
    resp_json = JSON.parse(resp)
    expect(resp_json.length).to eq(2)
    expect(resp_json[0]).to eq("sha256:abc123")
    expect(resp_json[1]).to eq("sha256:def456")
  end

  it "delete image" do
    stub_const("Docker::Image", double('docker-image'))
    image = double('image')
    expect(image).to receive(:id).and_return('sha256:abc123')
    expect(image).to receive(:delete)
    expect(Docker::Image).to receive(:all).and_return([image])
    delete '/image/sha256:abc123'
    expect(last_response.body).to eq('success')
    expect(last_response.status).to eq(200)
  end

  it "delete image error when none exists" do
    stub_const("Docker::Image", double('docker-image'))
    expect(Docker::Image).to receive(:all).and_return([])
    delete '/image/sha256:abc123'
    expect(last_response.body).to eq('Error: Image not found')
    expect(last_response.status).to eq(400)
  end

  it "delete image error when does not exist" do
    stub_const("Docker::Image", double('docker-image'))
    image = double('image')
    expect(image).to receive(:id).and_return('sha256:abc123')
    expect(Docker::Image).to receive(:all).and_return([image])
    delete '/image/sha256:def456'
    expect(last_response.body).to eq('Error: Image not found')
    expect(last_response.status).to eq(400)
  end

  it "stops image" do

  end

  it "runs task" do

  end

  it "build image" do

  end

end
