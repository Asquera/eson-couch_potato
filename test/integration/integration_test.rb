require './test/test_config'

class Post
  include CouchPotato::Persistence
  include Eson::Searchable
  
  property :title
end

class WithAfterHook
  include CouchPotato::Persistence
  include Eson::Searchable
  
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