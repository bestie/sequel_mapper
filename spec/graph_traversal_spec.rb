require "spec_helper"
require "support/mapper_setup"
require "support/sequel_persistence_setup"
require "support/seed_data_setup"
require "sequel_mapper"

RSpec.describe "Graph traversal" do
  include_context "mapper setup"
  include_context "sequel persistence setup"
  include_context "seed data setup"


  describe "assocaitions" do
    subject(:mapper) { mappers.fetch(:users) }

    let(:user_query) {
      mapper.where(id: "users/1")
    }

    let(:user) { user_query.first }

    it "finds data via the storage adapter" do
      expect(user_query.count).to eq(1)
    end

    it "maps the raw data from the store into domain objects" do
      expect(user_query.first.id).to eq("users/1")
      expect(user_query.first.first_name).to eq("Hansel")
    end

    it "handles has_many associations" do
      post = user.posts.first

      expect(post.subject).to eq("Cat biscuits")
    end

    it "handles nested has_many associations" do
      expect(
        user
          .posts.first
          .comments.first
          .body
      ).to eq("Trololol")
    end

    describe "lazy loading" do
      let(:post_factory) { double(:post_factory, call: nil) }

      it "loads has many associations lazily" do
        posts = user_query.first.posts

        expect(post_factory).not_to have_received(:call)
      end
    end

    it "maps belongs to assocations" do
      expect(user_query.first.posts.first.author.id)
        .to eq("users/1")
    end

    describe "identity map" do
      it "always returns (a proxy of) the same object for a given id" do
        expect(user_query.first.posts.first.author.__getobj__)
          .to be(user_query.first)
      end
    end

    it "maps deeply nested belongs to assocations" do
      expect(user_query.first.posts.first.comments.first.commenter.id)
        .to eq("user/2")
    end

    it "maps has many to many associations as has many through" do
      expect(user_query.first.posts.first.categories.map(&:id))
        .to match_array(["category/1", "category/2"])

      expect(user_query.first.posts.first.categories.to_a.last.posts.map(&:id))
        .to match_array(["post/1", "post/2"])
    end
  end
end
