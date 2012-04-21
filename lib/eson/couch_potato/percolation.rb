module Eson
  module CouchPotato
    module Percolation
      module Database
        def create_percolator(opts = {}, &block)
          index = opts.delete(:index) || elasticsearch_client.default_index
          type  = opts.delete(:type) || opts.delete(:name)

          query = Eson::Search::BaseQuery.new(&block)
          doc = opts.merge(query.to_query_hash)
          elasticsearch_client.index(:index => "_percolator",
                                     :type => index,
                                     :id => type,
                                     :doc => doc)
        end

        def percolate(doc, opts = {}, &block)
          index = opts.delete(:index) || elasticsearch_client.default_index
        
          elasticsearch_client.percolate(:index => index,
                                         :type => doc.class.name,
                                         :doc => doc.to_hash,
                                         &block)
        end
      end
      
      module Persistence
        def percolate(opts = {})
          database.percolate self, opts
        end

        def percolate_into(attribute, opts = {})
          self.send "#{attribute}=", percolate(opts = {})["matches"]
        end
      end
    end
  end
end

CouchPotato::Database.class_eval { 
  include Eson::CouchPotato::Percolation::Database
}
Eson::CouchPotato::Searchable.class_eval {
  include Eson::CouchPotato::Percolation::Persistence
}