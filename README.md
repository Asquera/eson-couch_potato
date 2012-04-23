# eson-couch_potato

`eson-couch_potato` is an integration of Eson into `couch_potato`. It allows to index CouchDB documents in ElasticSearch while using the interface you are used to. All documents will be indexed into an index with the same name as the CouchDB database.

## Usage

Indexing as an after-save hook:

```ruby
class WithAfterHook
  include CouchPotato::Persistence
  include Eson::CouchPotato::Searchable
  
  after_save :index
  
  property :title
end

w = WithAfterHook.new(:title => 'foobar')
CouchPotato.database.save_document(s)
```

You can also index documents by hand - they are not saved in CouchDB then.

```ruby
class Post
  include CouchPotato::Persistence
  include Eson::CouchPotato::Searchable

  property :title
end

p = Post.new(:title => 'foobar')
CouchPotato.database.index_document(p)
CouchPotato.database.search { query { match_all { } } }
```
## Predefined searches

Like CouchPotato allows to predefine views, Eson::CouchPotato allows you to predefine searches:

```ruby
class User
  include CouchPotato::Persistence
  include Eson::CouchPotato::Searchable

  after_save :index

  property :name
  
  search :by_name do
    query {
      term :name, :value => param(:name)
    }
  end
end

CouchPotato.database.search User.by_name(:name => "eson")
```

## MoreLikeThis

MoreLikeThis queries are easy as well:

```ruby
class Post
  include CouchPotato::Persistence
  include Eson::CouchPotato::Searchable

  property :title
end

p = Post.new(:title => 'foobar')
CouchPotato.database.index_document(p)
p.more_like_this
```

## Percolation

Eson::CouchPotato has an integration into the Percolation API:

```ruby
require 'eson/couch_potato/percolation'

CouchPotato.database.create_percolator(:name => "foo") do
  query {
    term :title, :value => "foobar"
  }
end
```
You can then run documents against it:

```ruby
p = Post.new(:title => "foobar")
CouchPotato.database.percolate(p)
```

Additionally, you can percolate each document and save the result in an attribute, even before saving:

```ruby
class WithPercolateHook
  include CouchPotato::Persistence
  include Eson::CouchPotato::Searchable
  
  before_create do
    percolate_into :tags
  end
  
  property :title
  property :tags
end

p = Post.new(:title => "foobar")
CouchPotato.database.save_document p
p.tags #=> ["foo"]
```

## Mappings

Eson::CouchPotato can generate ElasticSearch-Mappings for you. Some costumization is allowed, though very complex mappings should be written by hand by implementing ``#to_mapping_properties`` on your own:

```ruby
require 'eson/couch_potato/mappings'

class Nested
  include CouchPotato::Persistence
  include Eson::CouchPotato::Searchable

  property :title, :type => String, :index => :not_analyzed
  property :tags, :type => Array, :default => []
end

class Parent
  include CouchPotato::Persistence
  include Eson::CouchPotato::Searchable

  property :title, :type => String
  property :nested, :type => Nested
end

Parent.to_mapping # { "Parent" => {:properties => {:title => .... }}}
```

Nested documents will be indexed using the native `nested` type in ElasticSearch. This is currently not configurable.

Mappings can be published as ElasticSearch templates, which is recommendable:

```ruby
CouchPotato.database.register_template(name = "test", 
                                       pattern = "eson*", 
                                       models = Parent)
```

## Rivers

The second option to get documents into the ElasticSearch index is by running ElasticSearchs CouchDB-River. Eson::CouchPotato can set it up for you:

```ruby
require 'eson/couch_potato/rivers'

CouchPotato.database.start_river
CouchPotato.database.stop_river
```

It needs the `river-couchdb` and `lang-javascript` plugins.

## Remarks

For compatibility reasons, Eson::CouchPotato deactivates `json/add/symbol`. If you rely on its behaviour, file a bug and I will see whether I can fix that.

