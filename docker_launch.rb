class DockerLaunch

  def self.run(id, s, options, stdin_io)
    # Create container
    if options[:cmd].nil?
      c = Docker::Container.create('Image'=>id, 'Tty'=>false)
    else
      cmd = JSON.parse(options[:cmd])
      c = Docker::Container.create('Image'=>id, 'Tty'=>false, 'Cmd'=>cmd, 'OpenStdin'=>true, 'StdinOnce'=>true)
    end

    # Setup run thread
    t1 = Thread.new do
    #c.start
      c.tap(&:start).attach(:stream => true, :stdin => stdin_io, :stdout => true, :stderr => true, :logs => true, :tty => false) do |stream, chunk|
        s << {Stream: stream, Data: chunk}.to_json
      end
    end

    # Setup monitor thread
    t2 = Thread.new do
      while true
        state = Docker::Container.all(all: true, filters: { id: [c.id] }.to_json).first.info['State'].eql?('exited')
        if state == true
          puts "Detected container exit... waiting"
	  sleep 0.1
          puts "Force complete"
          t1.kill
          Thread.exit
        end
      end
    end

    # Wait until run thread complete
    t1.join

    # Ensure monitor is killed
    t2.kill

    # Retrieve logs
    #c.streaming_logs(stdout: true, stderr: true) do |s,c|
    #  puts "#{s}: #{c}"
    #end

    # Clean up
    c.delete
  end

end
