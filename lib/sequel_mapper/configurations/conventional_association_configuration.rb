module SequelMapper
  module Configurations
    require "sequel_mapper/one_to_many_association"
    require "sequel_mapper/many_to_many_association"
    require "sequel_mapper/many_to_one_association"
    require "sequel_mapper/collection_mutability_proxy"
    require "sequel_mapper/queryable_lazy_dataset_loader"
    require "sequel_mapper/lazy_object_proxy"

    class ConventionalAssociationConfiguration
      def initialize(mapping_name, mappings, dirty_map, datastore)
        @local_mapping_name = mapping_name
        @mappings = mappings
        @local_mapping = mappings.fetch(local_mapping_name)
        @dirty_map = dirty_map
        @datastore = datastore
      end

      attr_reader :local_mapping_name, :local_mapping, :mappings, :dirty_map, :datastore
      private     :local_mapping_name, :local_mapping, :mappings, :dirty_map, :datastore

      DEFAULT = :use_convention

      def has_many(association_name, key: DEFAULT, foreign_key: DEFAULT, mapping_name: DEFAULT, order_by: DEFAULT)
        defaults = {
          mapping_name: association_name,
          foreign_key: [INFLECTOR.singularize(local_mapping_name), "_id"].join.to_sym,
          key: :id,
          order_by: [[]],
        }

        specified = {
          mapping_name: mapping_name,
          foreign_key: foreign_key,
          key: key,
          order_by: order_by,
        }.reject { |_k,v|
          v == DEFAULT
        }

        config = defaults.merge(specified)
        associated_mapping_name = config.fetch(:mapping_name)
        associated_mapping = mappings.fetch(associated_mapping_name)

        local_mapping.add_association(
          association_name,
          has_many_mapper(**config)
        )
      end

      def belongs_to(association_name, key: DEFAULT, foreign_key: DEFAULT, mapping_name: DEFAULT)
        defaults = {
          key: :id,
          foreign_key: [association_name, "_id"].join.to_sym,
          mapping_name: INFLECTOR.pluralize(association_name).to_sym,
        }

        specified = {
          mapping_name: mapping_name,
          foreign_key: foreign_key,
          key: key,
        }.reject { |_k,v|
          v == DEFAULT
        }

        config = defaults.merge(specified)

        associated_mapping_name = config.fetch(:mapping_name)
        associated_mapping = mappings.fetch(associated_mapping_name)

        local_mapping.add_association(
          association_name,
          belongs_to_mapper(**config)
        )
      end

      def has_many_through(association_name, key: DEFAULT, foreign_key: DEFAULT, mapping_name: DEFAULT, through_mapping_name: DEFAULT, association_key: DEFAULT, association_foreign_key: DEFAULT)
        defaults = {
          mapping_name: association_name,
          key: :id,
          association_key: :id,
          foreign_key: [INFLECTOR.singularize(local_mapping_name), "_id"].join.to_sym,
          association_foreign_key: [INFLECTOR.singularize(association_name), "_id"].join.to_sym,
        }

        specified = {
          mapping_name: mapping_name,
          key: key,
          association_key: association_key,
          foreign_key: foreign_key,
          association_foreign_key: association_foreign_key,
        }.reject { |_k,v|
          v == DEFAULT
        }

        config = defaults.merge(specified)
        associated_mapping = mappings.fetch(config.fetch(:mapping_name))

        if through_mapping_name == DEFAULT
          through_mapping_name = [
            associated_mapping.relation_name,
            local_mapping.relation_name,
          ].sort.join("_to_")
        end

        join_table_name = mappings.fetch(through_mapping_name).namespace
        config = config
          .merge(
            through_mapping_name: through_mapping_name,
            through_dataset: datastore[join_table_name.to_sym],
          )

        local_mapping.add_association(
          association_name,
          has_many_through_mapper(**config)
        )
      end

      private

      def has_many_mapper(mapping_name:, key:, foreign_key:, order_by:)
        OneToManyAssociation.new(
          mapping_name: mapping_name,
          foreign_key: foreign_key,
          key: key,
          proxy_factory: collection_proxy_factory,
        )
      end

      def belongs_to_mapper(mapping_name:, key:, foreign_key:)
        ManyToOneAssociation.new(
          mapping_name: mapping_name,
          foreign_key: foreign_key,
          key: key,
          proxy_factory: single_object_proxy_factory,
        )
      end

      def has_many_through_mapper(mapping_name:, key:, foreign_key:, association_key:, association_foreign_key:, through_mapping_name:, through_dataset:)
        ManyToManyAssociation.new(
          mapping_name: mapping_name,
          key: key,
          foreign_key: foreign_key,
          association_key: association_key,
          association_foreign_key: association_foreign_key,
          through_mapping_name: through_mapping_name,
          through_dataset: through_dataset,
          proxy_factory: collection_proxy_factory,
        )
      end

      def single_object_proxy_factory
        ->(query:, loader:, preloaded_data:) {
          LazyObjectProxy.new(
            ->{ loader.call(query.first) },
            preloaded_data,
          )
        }
      end

      def collection_proxy_factory
        ->(query:, loader:, mapper:) {
          CollectionMutabilityProxy.new(
            QueryableLazyDatasetLoader.new(query, loader, mapper)
          )
        }
      end
    end
  end
end
