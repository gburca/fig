# coding: utf-8

require 'fig/command/action'
require 'fig/command/action/role/has_no_sub_action'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end

class Fig::Command::Action::ListRemote
  include Fig::Command::Action
  include Fig::Command::Action::Role::HasNoSubAction

  def options()
    return %w<--list-remote>
  end

  def descriptor_requirement()
    return :warn
  end

  def modifies_repository?()
    return false
  end

  def load_base_package?()
    return nil # Don't care.
  end

  def remote_operation_necessary?()
    return true
  end

  def execute()
    packages = @execution_context.repository.list_remote_packages

    if packages.empty?
      if $stdout.tty?
        puts 'No remote packages exist.'
      end
    else
      packages.sort.each {|item| puts item}
    end

    return EXIT_SUCCESS
  end
end
