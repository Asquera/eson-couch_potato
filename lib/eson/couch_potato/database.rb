module Eson
  module CouchPotato
    module Database
      def elasticsearch_client
        Eson::HTTP::Client.new(:default_index => couchrest_database.name)
      end
      
      def index_document(doc_or_options, opts = {})
        case doc_or_options
        when Hash
          elasticsearch_client.index(doc_or_options)["ok"]
        else
          opts.merge!(:type => doc_or_options.class.name, 
                      :doc => doc_or_options.to_hash)
          
          opts[:id] = doc_or_options.id if doc_or_options.id
          
          response = elasticsearch_client.index(opts)

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
      
      def more_like_this(doc, opts = {})
        opts.merge!(:id => doc.id,
                    :type => doc.class.name)

        parse_elasticsearch_result(
          elasticsearch_client.more_like_this(opts)
        )
      end
      alias :mlt :more_like_this
      
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
end
