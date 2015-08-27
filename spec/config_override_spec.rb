require "spec_helper"

require "support/mapper_setup"
require "support/sequel_persistence_setup"
require "support/seed_data_setup"
require "sequel_mapper"

require "sequel_mapper/configurations/conventional_configuration"

RSpec.describe "Configuration override" do
  include_context "mapper setup"
  include_context "sequel persistence setup"
  include_context "seed data setup"

  subject(:user_mapper) {
    SequelMapper.mapper(
      config: mapper_config,
      name: :users,
      datastore: datastore,
    )
  }

  let(:mapper_config) {
    SequelMapper::Configurations::ConventionalConfiguration.new(datastore)
      .setup_mapping(:users) { |users|
        users.has_many :posts, foreign_key: :author_id
      }
  }

  let(:user) {
    user_mapper.where(id: "users/1").first
  }

  context "override the root mapper factory" do
    context "with a Struct class" do
      before do
        mapper_config.setup_mapping(:users) do |config|
          config.factory(user_subclass)
        end
      end

      let(:user_subclass) { Class.new(User) }

      it "uses the class from the override" do
        expect(user.class).to be(user_subclass)
      end
    end
  end

  context "override an association" do
    context "with a callable factory" do
      before do
        mapper_config.setup_mapping(:posts) do |config|
          config.factory(override_post_factory)
        end
      end

      let(:post_subclass) { Class.new(Post) }

      let(:override_post_factory) {
        SequelMapper::StructFactory.new(post_subclass)
      }

      let(:posts) {
        user.posts
      }

      it "uses the specified factory" do
        expect(posts.first.class).to be(post_subclass)
      end
    end
  end

  context "override table names" do
    context "for just the top level mapping" do
      before do
        datastore.rename_table(:users, unconventional_table_name)
      end

      after do
        datastore.rename_table(unconventional_table_name, :users)
      end

      let(:mapper_config) {
        SequelMapper::Configurations::ConventionalConfiguration
        .new(datastore)
        .setup_mapping(:users) do |config|
          config.relation_name unconventional_table_name
        end
      }


      let(:datastore) { db_connection }

      let(:unconventional_table_name) {
        :users_is_called_this_weird_thing_perhaps_for_legacy_reasons
      }

      it "maps data from the specified relation" do
        expect(
          user_mapper.map(&:id)
        ).to eq(["users/1", "users/2"])
      end
    end

    context "for associated collections" do
      before do
        rename_all_the_tables
        setup_the_strange_table_name_mappings
      end

      after do
        undo_rename_all_the_tables
      end

      def rename_all_the_tables
        strange_table_name_map.each do |name, new_name|
          datastore.rename_table(name, new_name)
        end
      end

      def undo_rename_all_the_tables
        strange_table_name_map.each do |original_name, strange_name|
          datastore.rename_table(strange_name, original_name)
        end
      end

      def setup_the_strange_table_name_mappings
        mapper_config
          .setup_mapping(:users) do |config|
            config.relation_name strange_table_name_map.fetch(:users)
            config.has_many(:posts, foreign_key: :author_id)
          end
          .setup_mapping(:posts) do |config|
            config.relation_name strange_table_name_map.fetch(:posts)
            config.belongs_to(:author, mapping_name: :users)
            config.has_many_through(:categories, through_mapping_name: strange_table_name_map.fetch(:categories_to_posts))
          end
          .setup_mapping(:categories) do |config|
            config.relation_name strange_table_name_map.fetch(:categories)
            config.has_many_through(:posts, through_mapping_name: strange_table_name_map.fetch(:categories_to_posts))
          end
      end

      let(:strange_table_name_map) {
        {
          :users => :users_table_that_has_silly_name_perhaps_for_legacy_reasons,
          :posts => :thank_you_past_self_for_this_excellent_name,
          :categories => :these_are_the_categories_for_real,
          :categories_to_posts => :this_one_is_just_full_of_bees,
        }
      }

      it "maps data from the specified relation into a has many collection" do
        expect(
          user.posts.map(&:id)
        ).to eq(["posts/1", "posts/2"])
      end

      it "maps data from the specified relation into a `belongs_to` field" do
        expect(
          user.posts.first.author.__getobj__.object_id
        ).to eq(user.object_id)
      end
    end
  end
end
