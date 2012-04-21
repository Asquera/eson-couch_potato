module Eson
  module CouchPotato
    module Rivers
      def start_river(filter = nil)
        uri = Addressable::URI.parse(couchrest_database.host)
        doc = {
          :type => :couchdb,
          :couchdb => {
            :host => uri.host,
            :port => uri.port,
            :db => couchrest_database.name,
            :filter => filter,
            :script => "ctx._type = ctx.doc.#{JSON.create_id}"
          },
          :index => {
            :index => couchrest_database.name,
            :bulk_size => "100",
            :bulk_timeout => "10ms"
          }
        }
                
        elasticsearch_client.index(:index => "_river",
                                   :type => couchrest_database.name,
                                   :id => "_meta",
                                   :doc => doc)
      end
      
      def stop_river
        elasticsearch_client.delete(:index => "_river",
                                    :type => couchrest_database.name,
                                    :id => "_meta")
      end
    end
  end
end

CouchPotato::Database.class_eval{ include Eson::CouchPotato::Rivers }