require "forwardable"
require "sequel_mapper/dataset"

module SequelMapper
  class ManyToManyAssociation
    def initialize(mapping_name:, join_mapping_name:, foreign_key:, key:, proxy_factory:, association_foreign_key:, association_key:, order:)
      @mapping_name = mapping_name
      @join_mapping_name = join_mapping_name
      @foreign_key = foreign_key
      @key = key
      @proxy_factory = proxy_factory
      @association_foreign_key = association_foreign_key
      @association_key = association_key
      @order = order
    end

    def mapping_names
      [mapping_name, join_mapping_name]
    end

    attr_reader :mapping_name, :join_mapping_name

    attr_reader :foreign_key, :key, :proxy_factory, :association_key, :association_foreign_key, :order
    private     :foreign_key, :key, :proxy_factory, :association_key, :association_foreign_key, :order

    def build_proxy(data_superset:, loader:, record:)
     proxy_factory.call(
        query: build_query(data_superset, record),
        loader: ->(record_list) {
          record = record_list.first
          join_records = record_list.last

          loader.call(record, join_records)
        },
        mapping_name: mapping_name,
      )
    end

    def eager_superset((superset, join_superset), (associated_dataset))
      join_data = Dataset.new(
        join_superset
          .where(foreign_key => associated_dataset.select(association_key))
          .to_a
      )

      eager_superset = Dataset.new(
        superset.where(key => join_data.select(association_foreign_key)).to_a
      )

      [
        eager_superset,
        join_data,
      ]
    end

    def build_query((superset, join_superset), parent_record)
      ids = join_superset
              .where(foreign_key => foreign_key_value(parent_record))
              .select(association_foreign_key)

      order
        .apply(
          superset.where(
            key => ids
          )
        )
        .lazy.map { |record|
          [record, [foreign_keys(parent_record, record)]]
        }
    end

    def dump(parent_record, collection, &block)
      flat_list_of_records_and_join_records(parent_record, collection, &block)
    end

    def extract_foreign_key(_record)
      {}
    end

    def delete(parent_record, collection, &block)
      flat_list_of_just_join_records(parent_record, collection, &block)
    end

    private

    def flat_list_of_records_and_join_records(parent_record, collection, &block)
      record_join_record_pairs(parent_record, collection, &block).flatten(1)
    end

    def flat_list_of_just_join_records(parent_record, collection, &block)
      record_join_record_pairs(parent_record, collection, &block)
        .map { |(_records, join_records)| join_records }
        .flatten(1)
    end

    def record_join_record_pairs(parent_record, collection, &block)
      (collection || []).map { |associated_object|
        records = block.call(mapping_name, associated_object, _no_foreign_key = {})

        join_records = records.take(1).flat_map { |record|
          fks = foreign_keys(parent_record, record)
          block.call(join_mapping_name, fks, fks)
        }

        records + join_records
      }
    end

    def foreign_keys(parent_record, record)
      {
        foreign_key => foreign_key_value(parent_record),
        association_foreign_key => record.fetch(association_key),
      }
    end

    def foreign_key_value(record)
      record.fetch(key)
    end
  end
end
