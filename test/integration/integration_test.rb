require './test/test_config'
require 'eson/couch_potato/rivers'
require 'eson/couch_potato/mapping'
require 'eson/couch_potato/percolation'

class Post
  include CouchPotato::Persistence
  include Eson::CouchPotato::Searchable
  
  property :title
end

class WithAfterHook
  include CouchPotato::Persistence
  include Eson::CouchPotato::Searchable
  
  after_save :index
  
  property :title
end

context "Basic indexing" do
  setup do
    CouchPotato.database.elasticsearch_client.delete(:index => "_all")
    Post.new(:title => "foobar")
  end

  asserts("can be saved") {
    CouchPotato.database.index_document(topic)
  }.equals(true)
  
  asserts("can be found") {
    CouchPotato.database.elasticsearch_client.refresh
    sleep 1
    CouchPotato.database.search { query { match_all { } } }.results["hits"]["total"]
  }.equals(1)
end

context "Searching" do
  setup do
    p = Post.new(:title => "foobar")
    CouchPotato.database.index_document(p)
    CouchPotato.database.elasticsearch_client.refresh
    CouchPotato.database.search { query { match_all { } } }
  end
  
  asserts(:results).kind_of?(Hash)
  
  context "result" do
    setup do
      topic.first
    end
    
    asserts(:database).equals { CouchPotato.database }
    asserts(:_score).equals { 1.0 }
    asserts(:_type).equals { 'Post' }
    asserts(:_index).equals { 'eson-test' }
  end
end

context "Saving a document with after_save indexing" do
  setup do
    p = WithAfterHook.new(:title => "foobar")
    CouchPotato.database.save_document(p)
    p
  end
  
  asserts("can be retrieved using the same id") do
    CouchPotato.database.elasticsearch_client.get :type => "WithAfterHook", :id => topic.id
  end
  
  context "> retrieved object" do
    setup do
      CouchPotato.database.elasticsearch_client.get(:type => "WithAfterHook", :id => topic.id)["_source"]
    end

    denies(:new?)
    denies(:dirty?)
    
  end
end

context "More Like This" do
  setup do
    p, q = Post.new(:title => "foobar bar botz"), Post.new(:title => "foobar bar batz")
    CouchPotato.database.index_document(p)
    CouchPotato.database.index_document(q)
    CouchPotato.database.elasticsearch_client.refresh
    
    p.more_like_this(:min_doc_freq => 1, :min_term_freq => 1)
  end
  
  asserts(:results).kind_of?(Hash)
  
  context "result" do
    setup do
      topic.first
    end
    
    asserts(:database).equals { CouchPotato.database }
    asserts(:_score).kind_of?(Float)
    asserts(:_type).equals { 'Post' }
    asserts(:_index).equals { 'eson-test' }
  end
end

class Nested
  include CouchPotato::Persistence
  include Eson::CouchPotato::Searchable

  property :title, :type => String, :index => :not_analyzed
  property :tags, :type => Array, :default => [], :index_type => String
end

class SimilarNested
  include CouchPotato::Persistence
  include Eson::CouchPotato::Searchable

  property :title, :type => String, :index => :not_analyzed
  property :place, :type => String
end

class Parent
  include CouchPotato::Persistence
  include Eson::CouchPotato::Searchable

  property :title, :type => String
  property :nested, :type => Nested, :index_type => :nested
end

class ParentWithNestedArray
  include CouchPotato::Persistence
  include Eson::CouchPotato::Searchable
  
  property :nested, :type => Array, :nested_type => [Nested, SimilarNested]
end

context "Simple document mapping" do
  setup do
    Nested
  end
  
  asserts(:to_mapping_properties).equals({
    :title => { :type => :string, :index => :not_analyzed },
    :tags => { :type => :string },
    :created_at => { :type => :date, :format=>"yyyy/MM/dd HH:mm:ss Z" },
    :updated_at => { :type => :date, :format=>"yyyy/MM/dd HH:mm:ss Z" },
    JSON.create_id => { :type => :string }
  })
  
  asserts(:to_mapping).equals "Nested" => { :properties => Nested.to_mapping_properties }
end

context "Complex Document mapping" do
  setup do
    Parent
  end
  
  asserts(:to_mapping_properties).equals(
    :title => { :type => :string },
    :created_at => { :type => :date, :format=>"yyyy/MM/dd HH:mm:ss Z" }, 
    :updated_at => { :type => :date, :format=>"yyyy/MM/dd HH:mm:ss Z" },
    :nested => {
      :type => :nested,
      :properties => {
         :title => { :type => :string, :index => :not_analyzed },
         :tags => { :type => :string },
         :created_at => { :type => :date, :format=>"yyyy/MM/dd HH:mm:ss Z" },
         :updated_at => { :type => :date, :format=>"yyyy/MM/dd HH:mm:ss Z" },
         JSON.create_id => { :type => :string }
      }
    },
    JSON.create_id => { :type => :string }
  )
end

context "ParentWithNestedArray" do
  setup do
    ParentWithNestedArray
  end
  
  asserts(:to_mapping_properties).equals(
    :created_at => { :type => :date, :format=>"yyyy/MM/dd HH:mm:ss Z" }, 
    :updated_at => { :type => :date, :format=>"yyyy/MM/dd HH:mm:ss Z" },
    :nested => {
      :type => :nested,
      :properties => {
         :title => { :type => :string, :index => :not_analyzed },
         :tags => { :type => :string },
         :place => { :type => :string },
         :created_at => { :type => :date, :format=>"yyyy/MM/dd HH:mm:ss Z" },
         :updated_at => { :type => :date, :format=>"yyyy/MM/dd HH:mm:ss Z" },
         JSON.create_id => { :type => :string }
      }
    },
    JSON.create_id => { :type => :string }
  )
end

context "Templates" do
  helper(:parent_with_nested) do
    Parent.new :title => "parent", :nested => Nested.new(:title => "nested", :tags => %w(very cool))
  end
  
  setup do
    CouchPotato.database.elasticsearch_client.delete(:index => "_all")
    CouchPotato.database.elasticsearch_client.delete_template(:name => "test") rescue nil
    CouchPotato.database.register_template("test", "eson*", Parent)
    CouchPotato.database.index_document(parent_with_nested)
    CouchPotato.database.elasticsearch_client.refresh
  end
  
  asserts("nested search results lengths") do
    CouchPotato.database.search do
      query {
        nested(:path => :nested, :score_mode => "avg"){
          query {
            term :tags, :value => "very"
          }
        }
      }
    end.length
  end.equals(1)
end

class WithPercolateHook
  include CouchPotato::Persistence
  include Eson::CouchPotato::Searchable
  
  before_save do
    percolate_into :tags
  end
  
  property :title
  property :tags
end

context "Percolation" do
  setup do
    CouchPotato.database.create_percolator(:type => "foo") do
      query {
        term :title, :value => "foobar"
      }
    end
  end
  
  asserts("percolation matches") do
    p = Post.new(:title => "foobar")
    CouchPotato.database.percolate(p)["matches"]
  end.equals(%w(foo))
end

context "Percolation with before_save hook" do
  setup do
    CouchPotato.database.create_percolator(:type => "bar") do
      query {
        term :title, :value => "barfoo"
      }
    end
    
    w = WithPercolateHook.new(:title => "barfoo")
    CouchPotato.database.save_document w
    w
  end
  
  asserts(:tags).equals(%w(bar))
end

class WithPredefinedSearch
  include CouchPotato::Persistence
  include Eson::CouchPotato::Searchable
  
  property :title
  property :tags
  
  search :search_tags do
    query {
      term :tags, :value => param(:tag)
    }
  end
end

context "Predefined Searches" do
  setup do
    p = WithPredefinedSearch.new(:title => "foobar", :tags => %w(cool stuff))
    CouchPotato.database.index_document(p)
    CouchPotato.database.elasticsearch_client.refresh
    CouchPotato.database.search WithPredefinedSearch.search_tags(:tag => "cool")
  end
  
  asserts(:results).kind_of?(Hash)
  
  context "result" do
    setup do
      topic.first
    end
    
    asserts(:database).equals { CouchPotato.database }
    asserts(:_type).equals { 'WithPredefinedSearch' }
    asserts(:_index).equals { 'eson-test' }
  end
end

context "River" do
  setup do
    CouchPotato.database.elasticsearch_client.delete(:index => "_all")
    CouchPotato.database.start_river
    p = Post.new(:title => "foobar")
    CouchPotato.database.save_document(p)
    sleep 3 # rivers need a second to start
    CouchPotato.database.elasticsearch_client.get(:type => "Post", :id => p.id)["_source"]
  end
  
  teardown do
    CouchPotato.database.stop_river
  end
  
  asserts(:class).equals(Post)
end