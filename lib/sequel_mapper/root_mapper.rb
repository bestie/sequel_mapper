require "sequel_mapper/mapper_methods"

module SequelMapper
  class RootMapper
    include MapperMethods

    def initialize(datastore:, mapping:, dirty_map:)
      @datastore = datastore
      @mapping = mapping
      @dirty_map = dirty_map
    end

    attr_reader :datastore, :mapping, :dirty_map
    private     :datastore, :mapping, :dirty_map

    def where(criteria)
      relation
        .where(criteria)
        .map { |row| register_load(row) }
        .map { |row| mapping.load(row) }
    end

    def save(graph_root)
      upsert_if_dirty(mapping.dump(graph_root))
    end
  end
end
