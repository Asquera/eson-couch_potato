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
          elasticsearch_client.index(doc_or_options)
        else
          elasticsearch_client.index(:type => doc_or_options.class.name, 
                                     :doc => doc_or_options.to_hash)
        end
      end
      
      def search(opts = {}, &block)
        result = elasticsearch_client.search(opts, &block)
        hits = result["hits"]["hits"]
        docs = hits.map do |hit|
          hit['_source'].tap do |source|
            source.database = self if source.respond_to? :database
            source.extend SearchResult
            source._score = hit["_score"]
            source._index = hit["_index"]
            source._type = hit["_type"]
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
    attr_accessor :_score
    attr_accessor :_index
    attr_accessor :_type
  end
end

class CouchPotato::Database
  include Eson::CouchPotato::Database
end