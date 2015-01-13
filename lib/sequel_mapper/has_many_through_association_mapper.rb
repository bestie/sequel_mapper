require "sequel_mapper/abstract_association_mapper"
require "sequel_mapper/has_many_association_mapper_methods"

module SequelMapper
  class HasManyThroughAssociationMapper < AbstractAssociationMapper
    include HasManyAssociationMapperMethods

    def initialize(through_relation_name:, foreign_key:, association_foreign_key:, **args)
      @through_relation_name = through_relation_name
      @foreign_key = foreign_key
      @association_foreign_key = association_foreign_key
      super(**args)
    end

    attr_reader :through_relation_name, :foreign_key, :association_foreign_key
    private     :through_relation_name, :foreign_key, :association_foreign_key

    def load_for_row(row)
      proxy_with_dataset(
        eagerly_loaded_rows(row) || dataset(row),
      )
    end

    def save(source_object, collection)
      unless_already_persisted(collection) do |collection|
        persist_nodes(collection)
        associate_new_nodes(source_object, collection)
        dissociate_removed_nodes(source_object, collection)
      end
    end

    def eager_load_association(dataset, association_name)
      rows = dataset.to_a

      association_by_name(association_name).eager_load(foreign_key, rows)

      proxy_with_dataset(rows)
    end

    def eager_load(_foreign_key_field, rows)
      associated_ids = rows.map { |row| row.fetch(:id) }
      eager_dataset = dataset(id: associated_ids).to_a

      associated_ids.each do |id|
        @eager_loads[id] = eager_dataset
      end
    end

    private

    def proxy_with_dataset(dataset)
      proxy_factory.call(
        dataset,
        row_loader_func,
        self,
      )
    end

    def dataset(row)
      relation.where(:id => ids(row.fetch(:id)))
    end

    def ids(foreign_key_value)
      through_relation
        .select(association_foreign_key)
        .where(foreign_key => foreign_key_value)
    end

    def eagerly_loaded_rows(row)
      @eager_loads.fetch(row.fetch(:id), false)
    end

    def persist_nodes(collection)
      nodes_to_persist(collection).each do |object|
        upsert_if_dirty(mapping.dump(object))
      end
    end

    def associate_new_nodes(source_object, collection)
      added_nodes(collection).each do |node|
        through_relation.insert(
          foreign_key => source_object.public_send(:id),
          association_foreign_key => node.public_send(:id),
        )
      end
    end

    def dissociate_removed_nodes(source_object, collection)
      ids = removed_nodes(collection).map(&:id)

      through_relation
        .where(
          foreign_key => source_object.public_send(:id),
          association_foreign_key => ids,
        )
        .delete
    end

    def through_relation
      datastore[through_relation_name]
    end
  end
end