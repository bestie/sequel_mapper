require "sequel_mapper/abstract_association_mapper"

module SequelMapper
  # Association loads the correct associated row from the database,
  # constructs the correct proxy delegating to the RowMapper
  class BelongsToAssociationMapper < AbstractAssociationMapper
    def initialize(foreign_key:, **args)
      @foreign_key = foreign_key
      super(**args)
    end

    attr_reader :foreign_key
    private     :foreign_key

    def load_for_row(row)
      proxy_factory.call(eagerly_loaded(row) || dataset(row))
    end

    def save(_source_object, object)
      unless_already_persisted(object) do |object|
        if loaded?(object)
          upsert_if_dirty(mapping.dump(object))
        end
      end
    end

    def foreign_key_field(name, object)
      {
        foreign_key => object.public_send(name).public_send(:id)
      }
    end

    def eager_load(_foreign_key_field, rows)
      foreign_key_values = rows.map { |row| row.fetch(foreign_key) }
      ids = rows.map { |row| row.fetch(:id) }

      eager_object = relation.where(:id => foreign_key_values).first

      ids.each do |id|
        @eager_loads[id] = eager_object
      end
    end

    private

    def dataset(row)
      ->() {
        relation
          .where(:id => row.fetch(foreign_key))
          .map(&row_loader_func)
          .first
      }
    end

    def eagerly_loaded(row)
      associated_row = @eager_loads.fetch(row.fetch(:id), nil)

      if associated_row
        ->() { row_loader_func.call(associated_row) }
      else
        nil
      end
    end
  end
end