require 'eson'

module Eson
  module CouchPotato
    module Database
      def elasticsearch_client
        Eson::HTTP::Client.new(:default_index => couchrest_database.name)
      end
      
      def index_document(doc_or_options)
        case doc_or_options
        when Hash
          elasticsearch_client.index(doc_or_options)["ok"]
        else
          response = elasticsearch_client.index(:type => doc_or_options.class.name, 
                                                :doc => doc_or_options.to_hash)
          doc_or_options._id      = response["_id"]      unless doc_or_options._id
          doc_or_options._version = response["_version"] unless doc_or_options._version
          
          doc_or_options.database = self
          response["ok"]
        end
      end
      
      def search(opts = {}, &block)
        parse_elasticsearch_result(
          elasticsearch_client.search(opts, &block)
        )
      end
      
      def more_like_this(opts = {})
        parse_elasticsearch_result(
          elasticsearch_client.more_like_this(opts)
        )
      end
      
      def parse_elasticsearch_result(result)
        hits = result["hits"]["hits"]
        docs = hits.map do |hit|
          hit['_source'].tap do |source|
            source.database = self if source.respond_to? :database
            source.extend SearchResult
            source._score   = hit["_score"]
            source._index   = hit["_index"]
            source._type    = hit["_type"]
            source._version = hit["_version"]
            
            source._id = hit["_id"] unless source._id
            source._rev = hit["_rev"] unless source._rev
          end
        end
        docs.tap do |array|
          array.extend SearchResults
          array.results = result
        end
      end
    end
  end
  
  module SearchResults
    attr_accessor :results
    
    def total
      results["hits"]["total"]
    end
    
    def max_score
      results["hits"]["max_score"]
    end
  end
  
  module SearchResult
    attr_accessor :_score, :_index, :_type, :_version
  end
  
  module Searchable
    include SearchResult
    
    def self.included(base)
      base.extend(ClassMethods)
    end
    
    def index(opts = {})
      database.index_document opts.merge(:id => self.id,
                                         :type => self.class.name,
                                         :doc => self.to_hash)
    end
    
    def more_like_this(opts = {})
      database.more_like_this opts.merge(:id => self.id,
                                         :type => self.class.name)
    end
    
    module ClassMethods
      def to_mapping
        self.properties.list.inject({}) do |mapping, property|
          
          mapping[property.name] = begin
            options = if property.type == String
                        {:type => :string}
                      elsif property.type == Array
                        {:type => :string}
                      elsif property.type == Time
                        {:type => :date}
                      elsif property.type.ancestors.include?(::CouchPotato::Persistence)
                        map_child_type(property.type)
                      end

            property.options.each do |k,v|
              unless [:type, :default].include?(k)
                options[k] = v
              end
            end

            options
          end
          
          mapping
        end
      end
      
      def map_child_type(type)
        puts type
        {:type => :nested, :properties => type.to_mapping }
      end
    end
  end
end

class CouchPotato::Database
  include Eson::CouchPotato::Database
end

class CouchPotato::Persistence::SimpleProperty
  attr_reader :options
  
  alias :old_initialize :initialize
  
  def initialize(owner_clazz, name, options = {})
    @options = options
    old_initialize(owner_clazz, name, options)
  end
end
