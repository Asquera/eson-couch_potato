# eson-couch_potato

Integration of Eson into couch_potato.

## Usage

Indexing by hand:

```ruby
class Post
  include CouchPotato::Persistence
  include Eson::Searchable

  property :title
end

p = Post.new(:title => 'foobar')
CouchPotato.database.index_document(p)
CouchPotato.database.search { query { match_all { } } }
```

Indexing as an after-save hook:

```ruby
class WithAfterHook
  include CouchPotato::Persistence
  include Eson::Searchable
  
  after_save :index
  
  property :title
end

w = WithAfterHook.new(:title => 'foobar')
CouchPotato.database.save_document(s)
```