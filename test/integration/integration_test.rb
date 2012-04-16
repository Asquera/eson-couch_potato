require './test/test_config'

class Post
  include CouchPotato::Persistence

  property :title
end

context "Basic indexing" do
  setup do
    CouchPotato.database.elasticsearch_client.delete(:index => "_all")
    Post.new(:title => "foobar")
  end

  asserts("can be saved") {
    CouchPotato.database.index_document(topic)["ok"]
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