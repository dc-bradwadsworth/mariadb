# MariaDB is a module containing mariadb cookbook helper
module MariaDB
  # Helper module for mariadb cookbook
  module Helper
    require 'socket'
    require 'timeout'
    include Chef::Mixin::ShellOut

    def do_port_connect(ip, port)
      s = TCPSocket.new(ip, port)
      s.close
      true
    rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
      false
    end

    def port_open?(ip, port)
      begin
        Timeout.timeout(5) do
          return do_port_connect(ip, port)
        end
      rescue Timeout::Error
        false
      end
      false
    end

    # Trying to determine if we need to restart the mysql service
    def mariadb_service_restart_required?(ip, port, _socket)
      restart = false
      restart = true unless port_open?(ip, port)
      restart
    end

    # Helper to determine if running operating system shipped a package for
    # mariadb server & client. No galera shipped in any os yet.
    # @param [String] os_platform Indicate operating system type, e.g. centos
    # @param [String] os_version Indicate operating system version, e.g. 7.0
    def os_package_provided?(os_platform, os_version)
      package_provided = false
      case os_platform
      when 'centos', 'redhat'
        package_provided = true if os_version.to_i == 7
      when 'fedora'
        package_provided = true if os_version.to_i >= 19
      end
      package_provided
    end

    # Helper to determine mariadb server service name shipped by native package
    # If no native package available on this platform, return nil
    # @param [String] os_platform Indicate operating system type, e.g. centos
    # @param [String] os_version Indicate operating system version, e.g. 7.0
    def os_service_name(os_platform, os_version)
      return nil unless os_package_provided?(os_platform, os_version)
      service_name = 'mariadb'
      if os_platform == 'fedora' && os_version.to_i >= 19
        service_name = 'mysqld'
      end
      service_name
    end

    # Helper to determine whether to use os native package
    # @param [Boolean] prefer_os Indicate whether to prefer os native package
    # @param [String] os_platform Indicate operating system type, e.g. centos
    # @param [String] os_version Indicate operating system version, e.g. 7.0
    def use_os_native_package?(prefer_os, os_platform, os_version)
      return false unless prefer_os
      if os_package_provided?(os_platform, os_version)
        true
      else
        Chef::Log.warn 'prefer_os_package detected, but no native mariadb'\
          " package available on #{os_platform}-#{os_version}."\
          ' Fall back to use community package.'
        false
      end
    end

    def get_cluster_members(host, user, password=nil, port=3306)
       members = []
       query_command = "mysql -r -B -N -u #{user}"
       query_command += " -p#{password}" if password
       query_command += " -P #{port}"
       query_command += " -e \"SELECT VARIABLE_VALUE from information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = \'WSREP_INCOMING_ADDRESSES\';\""
       db_query = shell_out(query_command)
       db_query.run_command
       members = db_query.stdout.split(',') if db_query.stdout.is_a?(String)
        return members
    end
  end
end
