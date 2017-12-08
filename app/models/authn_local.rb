require 'timeout'
require 'fileutils'
require 'socket'

AuthnLocal = Struct.new(:socket, :queue_length, :timeout) do
  class << self
    def run socket:, queue_length:, timeout:
      socket ||= '/run/authn-local/.socket'
      socket_dir = File.dirname(socket)

      unless File.directory?(socket_dir)
        $stderr.puts "authn-local requires directory #{socket_dir.inspect} to exist and be a directory"
        $stderr.puts "authn-local will not be enabled"
        return
      end

      queue_length ||= 5
      queue_length = queue_length.to_i

      timeout ||= 1
      timeout = timeout.to_i

      AuthnLocal.new(socket, queue_length, timeout).run
    end
  end

  def run
    FileUtils.rm_rf socket

    server = UNIXServer.new socket

    trap(0) do
      # remove the socket on exit
      # alternatively it can be removed on startup
      # (or both)
      $stderr.puts "Removing socket #{socket}"
      File.unlink socket
    end

    server.listen queue_length

    puts "authn-local is listening at #{socket}"

    while conn = server.accept
      Timeout.timeout timeout do
        claims = conn.gets.strip
        begin
          conn.puts issue_token(claims)
        rescue
          $stderr.puts "Error in authn-local: #{$!.to_s}"
          conn.puts
        ensure
          conn.close
        end
      end
    end
  end

  def issue_token claims
    claims = JSON.parse(claims)
    claims = claims.slice("account", "sub", "exp", "cidr")
    account = claims.delete("account") or raise "'account' is required"
    raise "'sub' is required" unless claims['sub']
    Slosilo["authn:#{account}"].issue_jwt(claims).to_json
  end
end
