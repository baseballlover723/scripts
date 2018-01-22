require "socket"

# currently can handle sending and queuing up multiple data
class ForkPool
  MAX_LENGTH = 1_000_000

  def initialize(number_of_forks, queue, proc)
    @number_of_forks = number_of_forks
    @forks = []
    child_socket, parent_socket = Socket.pair(:UNIX, :DGRAM, 0)
    fork do
      parent_socket.close
      while true
        print "child: waiting for filepath\n"
        filepath = child_socket.recv MAX_LENGTH
        print "#{filepath.inspect}\n"
        break if filepath == ''
        result = proc.call(filepath)
        print "child: result: #{result}\n"
        child_socket.send(result, 0)
        print "child: sent result\n"
      end
    end
    child_socket.close
    parent_socket.send(queue.shift, 0)
    parent_socket.send(queue.shift, 0)
    sleep 5
    print "parent: waiting for result\n"
    yield parent_socket.recv MAX_LENGTH
    yield parent_socket.recv MAX_LENGTH
    parent_socket.send('', 0)
    parent_socket.close
    # @forks.each do |fork|
    #   Process.kill('HUP', fork)
    # end
    print "parent: got result\n"
    Process.waitall
  end

  def create_fork(&block)
    child_socket, parent_socket = Socket.pair(:UNIX, :DGRAM, 0)
    fork do
      parent_socket.close

      filepath = child_socket.recv MAX_LENGTH


    end
  end

end

def do_work(filepath)
  sleep 1
  filepath * 2
end


queue = ['test', 'path']
pool = ForkPool.new(8, queue, method(:do_work)) do |result|
  puts result
end

