require "delegate"

module SequelMapper
  class IdentityMap < SimpleDelegator
    def initialize(loader, identity_map = {})
      @loader = loader
      @identity_map = identity_map
      super(loader)
    end

    attr_reader :loader, :identity_map
    private     :loader, :identity_map

    def load(row)
      ensure_loaded_once(row.fetch(:id)) {
        loader.load(row)
      }
    end

    private

    def ensure_loaded_once(id, &block)
      identity_map.fetch(id) {
        identity_map.store(id, block.call)
      }
    end
  end
end
