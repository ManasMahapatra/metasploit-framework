##
# This module requires Metasploit: https://metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##

require 'msf/base/sessions/empire'

module MetasploitModule

  def initialize(info = {})
    super(
      update_info(
        info,
        'Name'        => 'Powershell Empire Windows',
        'Description' => 'Powershell Empire Windows',
        'Author'      => [
          'Brent Cook <bcook[at]rapid7.com>',
        ],
        'Platform'    => 'Windows',
        'Arch'        => ARCH_X64,
        'License'     => MSF_LICENSE,
        'Session'     => Msf::Sessions::EmpireWindowsShell
      )
    )
  end

  def generate_stage(opts = {})
  end
end
