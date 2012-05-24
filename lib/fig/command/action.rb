module Fig; end
class Fig::Command; end

module Fig::Command::Action
  def options()
    raise NotImplementedError
  end

  def descriptor_requirement()
    raise NotImplementedError
  end

  def allow_both_descriptor_and_file?()
    return false
  end

  def need_base_package?()
    raise NotImplementedError
  end

  def need_base_config?()
    raise NotImplementedError
  end

  def register_base_package?()
    raise NotImplementedError
  end

  def apply_base_config?()
    raise NotImplementedError
  end

  # Slurp data out of command-line options.
  def configure(options)
    # Do nothing by default.
    return
  end

  def execute(repository)
    raise NotImplementedError
  end
end