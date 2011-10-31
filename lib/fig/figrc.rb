require 'json'

require 'fig/applicationconfiguration'

module Fig
  class FigRC
    def self.find(retriever, override_path)
      # 1) pull from override path
      # 2) look in remote repo (using Retriever)
      return ApplicationConfiguration.new(nil) if override_path.nil?
      ApplicationConfiguration.new(
        JSON.parse(File::open(override_path).read)
      )
    end

    def self.load_from_handle(handle)
      ApplicationConfiguration.new(
        JSON.parse(handle.read)
      )
    end
  end
end

